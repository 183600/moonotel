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
  for i = 0; i < n; i = i + 1 {
    value = (value << 8) | (trace_id[i].to_uint64() & 0xFF)
  }
  value
}

fn ratio_threshold(ratio : Double) -> UInt64 {
  (ratio * 18446744073709551615.0).to_uint64()
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
  let threshold = ratio_threshold(ratio)
  {
    sample: fn(_parent, trace_id) {
      if ratio <= 0.0 {
        sampling_decision_drop()
      } else if ratio >= 1.0 {
        sampling_decision_record_and_sample()
      } else if trace_id_fraction(trace_id) < threshold {
        sampling_decision_record_and_sample()
      } else {
        sampling_decision_drop()
      }
    },
  }
}

// Delegate to `root` only when there is no valid parent; otherwise follow the
// parent's sampled flag.
pub fn Sampler::parent_based(root : Sampler) -> Sampler {
  {
    sample: fn(parent, trace_id) {
      match parent {
        Some(ctx) =>
          if ctx.is_valid() {
            if ctx.is_sampled() {
              sampling_decision_record_and_sample()
            } else {
              sampling_decision_drop()
            }
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
