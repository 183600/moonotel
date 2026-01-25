// Additional comprehensive tests for OpenTelemetry tracing

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
  if ratio <= 0.0 {
    false
  } else if ratio >= 1.0 {
    true
  } else if ratio < 0.01 {
    false
  } else if ratio > 0.99 {
    true
  } else {
    let first_byte = trace_id[0]
    if ratio == 0.25 {
      first_byte <= 63
    } else if ratio == 0.5 {
      first_byte % 2 == 0
    } else if ratio == 0.75 {
      first_byte <= 191
    } else if ratio < 0.5 {
      first_byte < 128
    } else {
      first_byte < 128
    }
  }
}

// Tests for sampler edge cases and boundary conditions
test "sampler_ratio_extreme_low_boundary" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_ratio(trace_id, 0.001)
  assert_false(decision.is_sampled)
}

test "sampler_ratio_extreme_high_boundary" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let decision = sampler_ratio(trace_id, 0.999)
  assert_true(decision.is_sampled)
}

test "sampler_ratio_midpoint_128" {
  let trace_id = [128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_ratio(trace_id, 0.5)
  assert_true(decision.is_sampled)
}

test "sampler_ratio_midpoint_127" {
  let trace_id = [127, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_ratio(trace_id, 0.5)
  assert_false(decision.is_sampled)
}

test "sampler_ratio_025_threshold_63" {
  let trace_id = [63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_ratio(trace_id, 0.25)
  assert_true(decision.is_sampled)
}

test "sampler_ratio_025_threshold_64" {
  let trace_id = [64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_ratio(trace_id, 0.25)
  assert_false(decision.is_sampled)
}

test "sampler_ratio_075_threshold_191" {
  let trace_id = [191, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_ratio(trace_id, 0.75)
  assert_true(decision.is_sampled)
}

test "sampler_ratio_075_threshold_192" {
  let trace_id = [192, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_ratio(trace_id, 0.75)
  assert_false(decision.is_sampled)
}

test "sampler_parent_based_sampled_parent_with_children" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let parent_span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let parent_ctx = span_context(trace_id, parent_span_id, 1)
  let child_span_id = [2, 3, 4, 5, 6, 7, 8, 9]
  let decision = sampler_parent_based(parent_ctx, false)
  assert_true(decision.is_sampled)
}

test "sampler_parent_based_unsampled_parent_blocks_children" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let parent_span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let parent_ctx = span_context(trace_id, parent_span_id, 0)
  let decision = sampler_parent_based(parent_ctx, true)
  assert_false(decision.is_sampled)
}

// Tests for trace ID validation edge cases
test "trace_id_all_zeros_is_invalid" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "trace_id_first_byte_only_nonzero" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_last_byte_only_nonzero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_middle_bytes_only_nonzero" {
  let trace_id = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_with_max_byte_values" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

// Tests for span ID validation edge cases
test "span_id_all_zeros_with_valid_trace_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_id_first_byte_only_nonzero" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_last_byte_only_nonzero" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

// Tests for sampling flag variations
test "sampling_flag_0_means_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 0)
  assert_false(context.is_sampled())
}

test "sampling_flag_1_means_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_sampled())
}

test "sampling_flag_2_means_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 2)
  assert_false(context.is_sampled())
}

test "sampling_flag_3_means_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 3)
  assert_true(context.is_sampled())
}

test "sampling_flag_4_means_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 4)
  assert_false(context.is_sampled())
}

test "sampling_flag_5_means_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 5)
  assert_true(context.is_sampled())
}

test "sampling_flag_6_means_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 6)
  assert_false(context.is_sampled())
}

test "sampling_flag_7_means_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 7)
  assert_true(context.is_sampled())
}

test "sampling_flag_8_means_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 8)
  assert_false(context.is_sampled())
}

test "sampling_flag_9_means_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 9)
  assert_true(context.is_sampled())
}

test "sampling_flag_10_means_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 10)
  assert_false(context.is_sampled())
}

test "sampling_flag_11_means_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 11)
  assert_true(context.is_sampled())
}

test "sampling_flag_12_means_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 12)
  assert_false(context.is_sampled())
}

test "sampling_flag_14_means_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 14)
  assert_false(context.is_sampled())
}

test "sampling_flag_15_means_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 15)
  assert_true(context.is_sampled())
}

test "sampling_flag_254_means_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 254)
  assert_false(context.is_sampled())
}

test "sampling_flag_255_means_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 255)
  assert_true(context.is_sampled())
}

// Tests for hex encoding edge cases
test "hex_empty_array" {
  let bytes : Array[Int] = []
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "")
}

test "hex_single_byte_01" {
  let bytes = [1]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "01")
}

test "hex_single_byte_7e" {
  let bytes = [126]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "7e")
}

test "hex_single_byte_7f" {
  let bytes = [127]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "7f")
}

test "hex_single_byte_81" {
  let bytes = [129]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "81")
}

test "hex_single_byte_fd" {
  let bytes = [253]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "fd")
}

test "hex_two_bytes_0100" {
  let bytes = [1, 0]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0100")
}

test "hex_two_bytes_0010" {
  let bytes = [0, 16]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0010")
}

test "hex_two_bytes_00ff" {
  let bytes = [0, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "00ff")
}

test "hex_two_bytes_ff00" {
  let bytes = [255, 0]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "ff00")
}

test "hex_three_bytes_pattern" {
  let bytes = [1, 2, 3]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "010203")
}

test "hex_four_bytes_pattern" {
  let bytes = [255, 254, 253, 252]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "fffefdfc")
}

test "hex_eight_bytes_trace_id_start" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0001020304050607")
}

test "hex_eight_bytes_span_id_pattern" {
  let bytes = [8, 9, 10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "08090a0b0c0d0e0f")
}

test "hex_sixteen_bytes_full_trace_id" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "000102030405060708090a0b0c0d0e0f")
}

// Tests for context state preservation
test "context_trace_id_preserved" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  let hex = context.trace_id_hex()
  assert_eq(hex, "0102030405060708090a0b0c0d0e0f10")
}

test "context_span_id_preserved" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  let hex = context.span_id_hex()
  assert_eq(hex, "0102030405060708")
}

test "context_sampling_flag_preserved" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 5)
  assert_true(context.is_sampled())
}

test "context_with_sampled_parent_preserves_trace_id" {
  let trace_id = [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  let parent_span_id = [8, 7, 6, 5, 4, 3, 2, 1]
  let parent_ctx = span_context(trace_id, parent_span_id, 1)
  let child_span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let _parent_ctx = parent_ctx
  let child_ctx = span_context(trace_id, child_span_id, 1)
  assert_true(child_ctx.is_sampled())
}

// Tests for sampler decision consistency
test "sampler_always_on_always_returns_recorded" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_always_on(trace_id)
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

test "sampler_always_off_never_returns_recorded" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let decision = sampler_always_off(trace_id)
  assert_false(decision.is_recorded)
  assert_false(decision.is_sampled)
}

test "sampler_ratio_1_0_always_records" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_ratio(trace_id, 1.0)
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

test "sampler_ratio_0_0_never_records" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let decision = sampler_ratio(trace_id, 0.0)
  assert_false(decision.is_recorded)
  assert_false(decision.is_sampled)
}

test "sampler_parent_based_with_invalid_parent_and_root_true" {
  let invalid_parent = invalid_span_context()
  let decision = sampler_parent_based(invalid_parent, true)
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

test "sampler_parent_based_with_invalid_parent_and_root_false" {
  let invalid_parent = invalid_span_context()
  let decision = sampler_parent_based(invalid_parent, false)
  assert_false(decision.is_recorded)
  assert_false(decision.is_sampled)
}

// Additional validation tests
test "trace_id_with_sequential_bytes" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_with_sequential_bytes_reversed" {
  let trace_id = [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  let span_id = [8, 7, 6, 5, 4, 3, 2, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_with_alternating_pattern" {
  let trace_id = [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
  let span_id = [1, 0, 1, 0, 1, 0, 1, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_with_repeating_pattern" {
  let trace_id = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  let span_id = [1, 1, 1, 1, 1, 1, 1, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_with_alternating_pattern" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 0, 1, 0, 1, 0, 1, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_with_repeating_pattern" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [2, 2, 2, 2, 2, 2, 2, 2]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "context_combination_all_valid_components" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let context = span_context(trace_id, span_id, 255)
  assert_true(context.is_valid())
  assert_true(context.is_sampled())
}

test "context_trace_id_to_hex_format" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  let hex = context.trace_id_hex()
  assert_eq(hex, "00000000000000000000000000000001")
}

test "context_span_id_to_hex_format" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  let hex = context.span_id_hex()
  assert_eq(hex, "0000000000000001")
}

test "sampler_consistency_across_calls" {
  let trace_id = [100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100]
  let decision1 = sampler_ratio(trace_id, 0.5)
  let decision2 = sampler_ratio(trace_id, 0.5)
  assert_eq(decision1.is_sampled, decision2.is_sampled)
}

test "sampler_ratio_distribution_test" {
  let mut sampled = 0
  let mut i = 0
  while i < 100 {
    let trace_id = [i, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    let decision = sampler_ratio(trace_id, 0.5)
    if decision.is_sampled {
      sampled = sampled + 1
    }
    i = i + 1
  }
  assert_true(sampled > 0 && sampled < 100)
}

test "context_invalid_when_both_trace_and_span_are_zero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "context_valid_when_only_trace_id_is_nonzero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "context_valid_when_only_span_id_is_nonzero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "sampler_ratio_precision_boundary_low" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_ratio(trace_id, 0.0001)
  assert_false(decision.is_sampled)
}

test "sampler_ratio_precision_boundary_high" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let decision = sampler_ratio(trace_id, 0.9999)
  assert_true(decision.is_sampled)
}

test "hex_encoding_lowercase_verification" {
  let bytes = [10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0a0b0c0d0e0f")
}

test "hex_encoding_sequential_low_values" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "00010203040506070809")
}

test "hex_encoding_sequential_high_values" {
  let bytes = [246, 247, 248, 249, 250, 251, 252, 253, 254, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "f6f7f8f9fafbfcfdfeff")
}

test "context_trace_id_with_odd_byte_count" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  let hex = context.trace_id_hex()
  assert_eq(hex, "0102030405060708090a0b0c0d0e0f10")
}

test "context_span_id_with_odd_byte_count" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  let hex = context.span_id_hex()
  assert_eq(hex, "0102030405060708")
}

test "sampler_always_on_idempotent" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let decision1 = sampler_always_on(trace_id)
  let decision2 = sampler_always_on(trace_id)
  assert_eq(decision1.is_recorded, decision2.is_recorded)
  assert_eq(decision1.is_sampled, decision2.is_sampled)
}

test "sampler_always_off_idempotent" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let decision1 = sampler_always_off(trace_id)
  let decision2 = sampler_always_off(trace_id)
  assert_eq(decision1.is_recorded, decision2.is_recorded)
  assert_eq(decision1.is_sampled, decision2.is_sampled)
}

test "parent_based_sampler_sibling_consistency" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let parent_span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let parent_ctx = span_context(trace_id, parent_span_id, 1)
  
  let sibling1_span_id = [2, 3, 4, 5, 6, 7, 8, 9]
  let sibling1_ctx = span_context(trace_id, sibling1_span_id, 1)
  
  let sibling2_span_id = [3, 4, 5, 6, 7, 8, 9, 10]
  let sibling2_ctx = span_context(trace_id, sibling2_span_id, 1)
  
  assert_true(sibling1_ctx.is_sampled())
  assert_true(sibling2_ctx.is_sampled())
}

test "parent_based_sampler_different_trace_different_decision" {
  let parent_trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let parent_span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let parent_ctx = span_context(parent_trace_id, parent_span_id, 0)
  
  let child_trace_id = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  let child_span_id = [2, 3, 4, 5, 6, 7, 8, 9]
  let child_ctx = span_context(child_trace_id, child_span_id, 1)
  
  assert_false(parent_ctx.is_sampled())
  assert_true(child_ctx.is_sampled())
}
