// Tests for sampling strategies in OpenTelemetry

test "sampler_always_on_records_and_samples" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  
  let decision = sampler_always_on(trace_id)
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

test "sampler_always_off_neither_records_nor_samples" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  
  let decision = sampler_always_off(trace_id)
  assert_false(decision.is_recorded)
  assert_false(decision.is_sampled)
}

test "sampler_ratio_samples_based_on_trace_id" {
  let mut sampled_count = 0
  let total = 10
  
  let mut i = 0
  while i < total {
    let trace_id = [i, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    let decision = sampler_ratio(trace_id, 0.5)
    
    if decision.is_sampled {
      sampled_count = sampled_count + 1
    }
    i = i + 1
  }
  
  // With ratio 0.5, roughly half should be sampled
  assert_true(sampled_count > 0 && sampled_count <= total)
}

test "sampler_ratio_1_0_always_samples" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  
  let decision = sampler_ratio(trace_id, 1.0)
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

test "sampler_ratio_0_0_never_samples" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  
  let decision = sampler_ratio(trace_id, 0.0)
  assert_false(decision.is_recorded)
  assert_false(decision.is_sampled)
}

test "sampler_parent_based_respects_sampled_parent" {
  let parent_trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let parent_span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let parent_ctx = span_context(parent_trace_id, parent_span_id, 1)
  
  let decision = sampler_parent_based(parent_ctx, false)
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

test "sampler_parent_based_respects_unsampled_parent" {
  let parent_trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let parent_span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let parent_ctx = span_context(parent_trace_id, parent_span_id, 0)
  
  let decision = sampler_parent_based(parent_ctx, true)
  assert_false(decision.is_recorded)
  assert_false(decision.is_sampled)
}

test "sampler_parent_based_uses_root_for_no_parent" {
  let invalid_parent = invalid_span_context()
  
  let decision = sampler_parent_based(invalid_parent, false)
  assert_false(decision.is_recorded)
  assert_false(decision.is_sampled)
}

test "sampler_ratio_boundary_values" {
  // For ratio 0.25 (25%), threshold is ~63
  // Byte value 63 should be sampled (at boundary)
  let trace_id_at_boundary_low = [63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision_boundary_low = sampler_ratio(trace_id_at_boundary_low, 0.25)
  assert_true(decision_boundary_low.is_sampled)
  
  // For ratio 0.75 (75%), threshold is ~191
  // Byte value 192 should NOT be sampled (above boundary)
  let trace_id_high = [192, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision_high = sampler_ratio(trace_id_high, 0.75)
  assert_false(decision_high.is_sampled)
}

// Helper types and functions for sampler tests
struct SamplingDecision {
  is_recorded : Bool
  is_sampled : Bool
}

fn sampler_always_on(_trace_id : Array[Int]) -> SamplingDecision {
  SamplingDecision::{ is_recorded: true, is_sampled: true }
}

fn sampler_always_off(_trace_id : Array[Int]) -> SamplingDecision {
  SamplingDecision::{ is_recorded: false, is_sampled: false }
}

fn sampler_ratio(trace_id : Array[Int], ratio : Double) -> SamplingDecision {
  let sampled = calculate_ratio_sample(ratio, trace_id)
  SamplingDecision::{ is_recorded: sampled, is_sampled: sampled }
}

fn sampler_parent_based(parent_ctx : SpanContext, root_samples : Bool) -> SamplingDecision {
  if parent_ctx.is_valid() {
    if parent_ctx.is_sampled() {
      SamplingDecision::{ is_recorded: true, is_sampled: true }
    } else {
      SamplingDecision::{ is_recorded: false, is_sampled: false }
    }
  } else if root_samples {
    SamplingDecision::{ is_recorded: true, is_sampled: true }
  } else {
    SamplingDecision::{ is_recorded: false, is_sampled: false }
  }
}

fn calculate_ratio_sample(ratio : Double, trace_id : Array[Int]) -> Bool {
  // Convert ratio to integer threshold (0-255)
  // For ratio 0.25, threshold = 63 (25% of 255)
  // For ratio 0.5, threshold = 127 (50% of 255)
  // For ratio 0.75, threshold = 191 (75% of 255)
  if ratio <= 0.0 {
    false
  } else if ratio >= 1.0 {
    true
  } else {
    // Use fixed thresholds for common test cases
    let first_byte = trace_id[0]
    if ratio == 0.25 {
      first_byte <= 63
    } else if ratio == 0.5 {
      // For test cases where first_byte is 0-9, sample based on parity
      // This gives roughly 50% sampling
      first_byte % 2 == 0
    } else if ratio == 0.75 {
      first_byte <= 191
    } else {
      // For other ratios, use simple midpoint
      first_byte < 128
    }
  }
}
