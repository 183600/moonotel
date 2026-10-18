// Sampling decisions and the built-in samplers.
//
// A sampler decides, for every new span, whether the span is recorded
// (attributes/events are kept) and sampled (the span is exported and the
// sampled flag is propagated downstream).

// Result of a sampling decision.
pub(all) struct SamplingDecision {
  is_recorded : Bool
  is_sampled : Bool
} derive(Eq, @debug.Debug)

// Record and export the span (RECORD_AND_SAMPLE)
pub fn sampling_decision_record_and_sample() -> SamplingDecision {
  { is_recorded: true, is_sampled: true }
}

// Record locally but do not export (RECORD_ONLY)
pub fn sampling_decision_record_only() -> SamplingDecision {
  { is_recorded: true, is_sampled: false }
}

// Do not record and do not export (DROP)
pub fn sampling_decision_drop() -> SamplingDecision {
  { is_recorded: false, is_sampled: false }
}

// Compose the trace ID's leading 8 bytes into an unsigned 64-bit integer.
// This is the value used by ratio-based sampling (consistent across SDKs).
fn trace_id_fraction(trace_id : Array[Int]) -> UInt64 {
  let mut value : UInt64 = 0
  let n = if trace_id.length() < 8 { trace_id.length() } else { 8 }
  let mut i = 0
  while i + 4 <= n {
    let b0 = trace_id.unsafe_get(i).to_uint64() & 0xFF
    let b1 = trace_id.unsafe_get(i + 1).to_uint64() & 0xFF
    let b2 = trace_id.unsafe_get(i + 2).to_uint64() & 0xFF
    let b3 = trace_id.unsafe_get(i + 3).to_uint64() & 0xFF
    value = (value << 32) | (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    i = i + 4
  }
  while i < n {
    value = (value << 8) | (trace_id.unsafe_get(i).to_uint64() & 0xFF)
    i = i + 1
  }
  value
}

// The threshold is `ratio * 2^63` and the trace ID is shifted right by one bit
// before the comparison, keeping the arithmetic within the 63 bits of integer
// precision of a double. This matches the algorithm used by the OpenTelemetry
// SDKs in other languages, so the same trace ID is sampled everywhere.
fn ratio_threshold(ratio : Double) -> UInt64 {
  (ratio * 9223372036854775808.0).to_uint64()
}

// A Sampler is a function from (parent SpanContext?, trace ID) to a decision.
pub struct Sampler {
  sample : (@api.SpanContext?, Array[Int]) -> SamplingDecision
}

// Always sample every span.
pub fn Sampler::always_on() -> Sampler {
  {
    sample: fn(_parent, _trace_id) {
      sampling_decision_record_and_sample()
    },
  }
}

// Never sample any span.
pub fn Sampler::always_off() -> Sampler {
  {
    sample: fn(_parent, _trace_id) {
      sampling_decision_drop()
    },
  }
}

// Record every span locally but never sample (never export).
pub fn Sampler::record_only() -> Sampler {
  {
    sample: fn(_parent, _trace_id) {
      sampling_decision_record_only()
    },
  }
}

// Sample a deterministic fraction of traces based on the trace ID.
// `ratio` is clamped: values <= 0 never sample, values >= 1 always sample.
pub fn Sampler::trace_id_ratio_based(ratio : Double) -> Sampler {
  if ratio <= 0.0 {
    return Sampler::always_off()
  }
  if ratio >= 1.0 {
    return Sampler::always_on()
  }
  let threshold = ratio_threshold(ratio)
  {
    sample: fn(_parent, trace_id) {
      if (trace_id_fraction(trace_id) >> 1) < threshold {
        sampling_decision_record_and_sample()
      } else {
        sampling_decision_drop()
      }
    },
  }
}

// Delegate to `root` only when there is no valid parent; otherwise delegate
// to the sampler selected by the parent's origin and sampled flag. The
// optional delegates default to the OpenTelemetry specification values:
// always-on for sampled parents and always-off for unsampled parents, for
// both remote and local parents.
pub fn Sampler::parent_based(
  root : Sampler,
  remote_parent_sampled? : Sampler,
  remote_parent_not_sampled? : Sampler,
  local_parent_sampled? : Sampler,
  local_parent_not_sampled? : Sampler
) -> Sampler {
  let remote_sampled = match remote_parent_sampled {
    Some(value) => value
    None => Sampler::always_on()
  }
  let remote_not_sampled = match remote_parent_not_sampled {
    Some(value) => value
    None => Sampler::always_off()
  }
  let local_sampled = match local_parent_sampled {
    Some(value) => value
    None => Sampler::always_on()
  }
  let local_not_sampled = match local_parent_not_sampled {
    Some(value) => value
    None => Sampler::always_off()
  }
  {
    sample: fn(parent, trace_id) {
      match parent {
        Some(ctx) =>
          if ctx.is_valid() {
            let sampled = (ctx.trace_flags() & 1) != 0
            let delegate = if ctx.is_remote() {
              if sampled { remote_sampled } else { remote_not_sampled }
            } else if sampled {
              local_sampled
            } else {
              local_not_sampled
            }
            delegate.should_sample(Some(ctx), trace_id)
          } else {
            root.should_sample(None, trace_id)
          }
        None => root.should_sample(None, trace_id)
      }
    },
  }
}

// Run the sampler for the given parent context and trace ID.
pub fn Sampler::should_sample(
  self : Sampler,
  parent : @api.SpanContext?,
  trace_id : Array[Int]
) -> SamplingDecision {
  (self.sample)(parent, trace_id)
}

// The ratio configured through `OTEL_TRACES_SAMPLER_ARG`, or 1.0 when the
// variable is absent, not a number, or NaN.
fn sampler_ratio_from_env() -> Double {
  match @env.get_env_var("OTEL_TRACES_SAMPLER_ARG") {
    Some(value) => {
      let ratio = try {
        @string.parse_double(value.trim())
      } catch {
        _ => 1.0
      }
      if ratio.is_nan() {
        1.0
      } else {
        ratio
      }
    }
    None => 1.0
  }
}

// Build a sampler from the standard `OTEL_TRACES_SAMPLER` and
// `OTEL_TRACES_SAMPLER_ARG` environment variables:
//
// - `always_on`, `always_off`
// - `traceidratio`, `parentbased_traceidratio` (ratio argument)
// - `parentbased_always_on` (the default), `parentbased_always_off`
//
// Unknown values fall back to the default `parentbased_always_on` sampler,
// as required by the OpenTelemetry specification.
pub fn Sampler::from_env() -> Sampler {
  let name = match @env.get_env_var("OTEL_TRACES_SAMPLER") {
    Some(value) => value.trim()
    None => ""
  }
  match name {
    "always_on" => Sampler::always_on()
    "always_off" => Sampler::always_off()
    "traceidratio" => Sampler::trace_id_ratio_based(sampler_ratio_from_env())
    "parentbased_traceidratio" =>
      Sampler::parent_based(
        Sampler::trace_id_ratio_based(sampler_ratio_from_env()),
      )
    "parentbased_always_off" => Sampler::parent_based(Sampler::always_off())
    "parentbased_always_on" | "" => Sampler::parent_based(Sampler::always_on())
    _ => Sampler::parent_based(Sampler::always_on())
  }
}

pub extend SamplingDecision with Eq::{not_equal, equal}
pub extend SamplingDecision with @debug.Debug::{to_repr}
