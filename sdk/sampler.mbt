// Sampling decisions and the built-in samplers.
//
// A sampler decides, for every new span, whether the span is recorded
// (attributes/events are kept) and sampled (the span is exported and the
// sampled flag is propagated downstream).

// Result of a sampling decision.

///|
pub(all) struct SamplingDecision {
  is_recorded : Bool
  is_sampled : Bool
} derive(Eq, @debug.Debug)

// Record and export the span (RECORD_AND_SAMPLE)

///|
pub fn sampling_decision_record_and_sample() -> SamplingDecision {
  { is_recorded: true, is_sampled: true, }
}

// Record locally but do not export (RECORD_ONLY)

///|
pub fn sampling_decision_record_only() -> SamplingDecision {
  { is_recorded: true, is_sampled: false, }
}

// Do not record and do not export (DROP)

///|
pub fn sampling_decision_drop() -> SamplingDecision {
  { is_recorded: false, is_sampled: false, }
}

// Compose the trace ID's leading 8 bytes into an unsigned 64-bit integer.
// This is the value used by ratio-based sampling; the OpenTelemetry
// specification does not mandate a particular byte range or algorithm, so
// different SDKs may hash different bytes.

///|
fn trace_id_fraction(trace_id : Array[Int32]) -> UInt64 {
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

///|
fn ratio_threshold(ratio : Double) -> UInt64 {
  (ratio * 9223372036854775808.0).to_uint64()
}

// Everything a sampler may inspect when deciding whether to record and
// export a span. Following the OpenTelemetry specification, the sampling
// decision can depend on the parent, the trace ID, the span name and kind,
// and the attributes and links passed at span creation.

///|
pub(all) struct SamplingParameters {
  parent : @api.SpanContext?
  trace_id : Array[Int32]
  name : String
  kind : @api.SpanKind
  attributes : Map[String, AttributeValue]
  links : Array[SpanLink]
}

// A Sampler turns sampling parameters into a decision and carries a
// human-readable description of its configuration.

///|
pub struct Sampler {
  description : String
  sample : (SamplingParameters) -> SamplingDecision
}

// Build a sampler from a description and a sampling function. The function is
// called with the parent, trace ID, name, kind, attributes and links of every
// new span, so samplers can implement attribute- or route-based policies.

///|
pub fn Sampler::new(
  description : String,
  sample : (SamplingParameters) -> SamplingDecision,
) -> Sampler {
  { description, sample, }
}

// The description of this sampler, following the format required by the
// OpenTelemetry specification (e.g. `AlwaysOnSampler`,
// `TraceIdRatioBased{0.5}`).

///|
pub fn Sampler::description(self : Sampler) -> String {
  self.description
}

// Always sample every span.

///|
pub fn Sampler::always_on() -> Sampler {
  Sampler::new("AlwaysOnSampler", fn(_parameters) {
    sampling_decision_record_and_sample()
  })
}

// Never sample any span.

///|
pub fn Sampler::always_off() -> Sampler {
  Sampler::new("AlwaysOffSampler", fn(_parameters) { sampling_decision_drop() })
}

// Record every span locally but never sample (never export).

///|
pub fn Sampler::record_only() -> Sampler {
  Sampler::new("RecordOnlySampler", fn(_parameters) {
    sampling_decision_record_only()
  })
}

// Sample a deterministic fraction of traces based on the trace ID.
// `ratio` is clamped into `[0..1]`: values <= 0 (and -Infinity) never sample,
// values >= 1 (and +Infinity) always sample, and NaN behaves like 1.0,
// matching the environment-variable path. The description keeps the
// `TraceIdRatioBased` identity of the sampler, as required by the
// specification.

///|
pub fn Sampler::trace_id_ratio_based(ratio : Double) -> Sampler {
  let clamped = if ratio.is_nan() {
    1.0
  } else if ratio < 0.0 {
    0.0
  } else if ratio > 1.0 {
    1.0
  } else {
    ratio
  }
  let threshold = ratio_threshold(clamped)
  Sampler::new("TraceIdRatioBased{" + clamped.to_string() + "}", fn(parameters) {
    if trace_id_fraction(parameters.trace_id) >> 1 < threshold {
      sampling_decision_record_and_sample()
    } else {
      sampling_decision_drop()
    }
  })
}

// Delegate to `root` only when there is no valid parent; otherwise delegate
// to the sampler selected by the parent's origin and sampled flag. The
// optional delegates default to the OpenTelemetry specification values:
// always-on for sampled parents and always-off for unsampled parents, for
// both remote and local parents.

///|
pub fn Sampler::parent_based(
  root : Sampler,
  remote_parent_sampled? : Sampler,
  remote_parent_not_sampled? : Sampler,
  local_parent_sampled? : Sampler,
  local_parent_not_sampled? : Sampler,
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
  Sampler::new("ParentBased{" + root.description() + "}", fn(parameters) {
    match parameters.parent {
      Some(ctx) =>
        if ctx.is_valid() {
          let sampled = (ctx.trace_flags() & 1) != 0
          let delegate = if ctx.is_remote() {
            if sampled {
              remote_sampled
            } else {
              remote_not_sampled
            }
          } else if sampled {
            local_sampled
          } else {
            local_not_sampled
          }
          delegate.should_sample_parameters(
            { ..parameters, parent: Some(ctx), },
          )
        } else {
          root.should_sample_parameters({ ..parameters, parent: None, })
        }
      None => root.should_sample_parameters(parameters)
    }
  })
}

// Run the sampler with the full set of sampling parameters.

///|
pub fn Sampler::should_sample_parameters(
  self : Sampler,
  parameters : SamplingParameters,
) -> SamplingDecision {
  (self.sample)(parameters)
}

// Run the sampler for the given parent context and trace ID. Span-specific
// parameters are empty: the name is "", the kind is `Internal`, and no
// attributes or links are supplied. Use `should_sample_parameters` to expose
// them to a custom sampler.

///|
pub fn Sampler::should_sample(
  self : Sampler,
  parent : @api.SpanContext?,
  trace_id : Array[Int32],
) -> SamplingDecision {
  self.should_sample_parameters({
    parent,
    trace_id,
    name: "",
    kind: @api.SpanKind::Internal,
    attributes: Map([]),
    links: [],
  })
}

// The ratio configured through `OTEL_TRACES_SAMPLER_ARG`, or 1.0 when the
// variable is absent, not a number, NaN, or outside the `[0..1]` range.

///|
fn sampler_ratio_from_env() -> Double {
  match @env.get_env_var("OTEL_TRACES_SAMPLER_ARG") {
    Some(value) =>
      match parse_decimal_double(value.trim()) {
        Some(ratio) =>
          if ratio.is_nan() || ratio < 0.0 || ratio > 1.0 {
            1.0
          } else {
            ratio
          }
        None => 1.0
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
// The sampler name is an enum value and is matched case-insensitively.
// Unknown values fall back to the default `parentbased_always_on` sampler,
// as required by the OpenTelemetry specification.

///|
pub fn Sampler::from_env() -> Sampler {
  let name = match @env.get_env_var("OTEL_TRACES_SAMPLER") {
    Some(value) => value.trim().to_lower()
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

///|
pub extend SamplingDecision with Eq::{not_equal, equal}

///|
pub extend SamplingDecision with @debug.Debug::{to_repr}
