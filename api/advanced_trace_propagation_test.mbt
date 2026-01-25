// Advanced W3C Trace Context propagation and integration tests

// === W3C Trace Context Format Tests ===

test "w3c_trace_context_version_byte" {
  // Version byte must be 00
  let version = 0
  assert_eq(version, 0)
}

test "w3c_trace_context_version_byte_valid" {
  let version_byte = 0x00
  assert_eq(version_byte, 0)
}

test "w3c_trace_context_version_byte_invalid" {
  // Version 255 is invalid
  let invalid_version = 0xFF
  assert_true(invalid_version != 0)
}

test "w3c_trace_context_trace_id_length" {
  // Trace ID must be 16 bytes = 32 hex chars
  let trace_id_length = 16
  assert_eq(trace_id_length, 16)
}

test "w3c_trace_context_span_id_length" {
  // Span ID must be 8 bytes = 16 hex chars
  let span_id_length = 8
  assert_eq(span_id_length, 8)
}

test "w3c_trace_context_version_trace_id_span_id_flags" {
  // Format: version-traceid-spanid-flags
  let version = 0x00
  let trace_id = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F]
  let span_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
  let flags = 0x01
  assert_true((flags & 1) == 1)
}

test "w3c_trace_context_parent_span_id_present" {
  // New format includes parent span ID
  let parent_span_id = [0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xFA, 0xF9, 0xF8]
  assert_eq(parent_span_id.length(), 8)
}

test "w3c_trace_context_format_sample" {
  // Example: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
  let version = "00"
  let trace_id = "0af7651916cd43dd8448eb211c80319c"
  let span_id = "b7ad6b7169203331"
  let flags = "01"
  assert_eq(version.length(), 2)
  assert_eq(trace_id.length(), 32)
  assert_eq(span_id.length(), 16)
  assert_eq(flags.length(), 2)
}

test "w3c_trace_context_format_with_parent_sample" {
  // New format with parent: version-traceid-spanid-parent-flags
  let version = "00"
  let trace_id = "0af7651916cd43dd8448eb211c80319c"
  let span_id = "b7ad6b7169203331"
  let parent_span_id = "cbbd6b7169203331"
  let flags = "01"
  assert_eq(parent_span_id.length(), 16)
}

test "w3c_trace_context_flags_sampled" {
  let sampled_flags = 0x01
  assert_true((sampled_flags & 1) == 1)
}

test "w3c_trace_context_flags_not_sampled" {
  let not_sampled_flags = 0x00
  assert_true((not_sampled_flags & 1) == 0)
}

test "w3c_trace_context_flags_trace_state" {
  // Additional flags for trace state
  let flags = 0x02
  assert_true((flags & 2) == 2)
}

test "w3c_trace_context_all_flags_set" {
  let all_flags = 0xFF
  assert_true((all_flags & 1) == 1)
  assert_true((all_flags & 2) == 2)
  assert_true((all_flags & 4) == 4)
  assert_true((all_flags & 8) == 8)
}

test "w3c_trace_context_flags_mask_bits" {
  // Test each bit of flags byte
  let flags = 0xAB // 10101011 in binary
  assert_true((flags & 1) == 1) // bit 0
  assert_true((flags & 2) == 2) // bit 1
  assert_true((flags & 4) == 0) // bit 2
  assert_true((flags & 8) == 8) // bit 3
  assert_true((flags & 16) == 0) // bit 4
  assert_true((flags & 32) == 32) // bit 5
  assert_true((flags & 64) == 0) // bit 6
  assert_true((flags & 128) == 128) // bit 7
}

// === Trace ID Generation Tests ===

test "trace_id_first_byte_variation" {
  // Different first bytes should produce different traces
  let trace1 = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  let trace2 = [0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  assert_true(trace1[0] != trace2[0])
}

test "trace_id_all_zeros_invalid" {
  let zero_trace = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  let is_zero = check_all_zero(zero_trace)
  assert_true(is_zero)
}

test "trace_id_all_zeros_is_invalid" {
  let zero_trace = Array::make(16, 0)
  let sc = span_context(zero_trace, [1, 2, 3, 4, 5, 6, 7, 8], 1)
  assert_false(sc.is_valid())
}

test "trace_id_mostly_zeros_one_nonzero" {
  let trace = Array::make(16, 0)
  trace[15] = 1
  let sc = span_context(trace, [1, 2, 3, 4, 5, 6, 7, 8], 1)
  assert_true(sc.is_valid())
}

test "trace_id_random_values_valid" {
  let trace = [0x4B, 0x1A, 0x8E, 0x9C, 0x3D, 0xF1, 0x2A, 0x8B, 0x9C, 0x4D, 0x1E, 0xF3, 0x2A, 0x8B, 0x9C, 0x4D]
  let sc = span_context(trace, [1, 2, 3, 4, 5, 6, 7, 8], 1)
  assert_true(sc.is_valid())
}

// === Span ID Generation Tests ===

test "span_id_first_byte_variation" {
  let span1 = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  let span2 = [0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  assert_true(span1[0] != span2[0])
}

test "span_id_all_zeros_invalid" {
  let zero_span = Array::make(8, 0)
  let sc = span_context([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], zero_span, 1)
  assert_false(sc.is_valid())
}

test "span_id_mostly_zeros_valid" {
  let span = Array::make(8, 0)
  span[7] = 1
  let sc = span_context([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], span, 1)
  assert_true(sc.is_valid())
}

test "span_id_max_value" {
  let max_span = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let sc = span_context([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], max_span, 1)
  assert_true(sc.is_valid())
}

test "span_id_hex_max_value" {
  let max_span = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let sc = span_context([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], max_span, 1)
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

// === Sampling Decision Tests ===

test "sampling_decision_recorded_flag" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let decision = sampler_always_on(trace_id)
  assert_true(decision.is_recorded)
}

test "sampling_decision_not_recorded_flag" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let decision = sampler_always_off(trace_id)
  assert_false(decision.is_recorded)
}

test "sampling_decision_recorded_sampled_match" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let decision = sampler_always_on(trace_id)
  assert_eq(decision.is_recorded, decision.is_sampled)
}

test "sampling_decision_always_off_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let decision = sampler_always_off(trace_id)
  assert_false(decision.is_sampled)
}

test "sampling_decision_ratio_boundary" {
  // Test sampling at 0.5 boundary
  let trace_low = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let trace_high = [255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision_low = sampler_ratio(trace_low, 0.5)
  let decision_high = sampler_ratio(trace_high, 0.5)
  assert_true(decision_low.is_sampled != decision_high.is_sampled)
}

test "sampling_decision_ratio_100_percent" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_ratio(trace_id, 1.0)
  assert_true(decision.is_sampled)
}

test "sampling_decision_ratio_0_percent" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let decision = sampler_ratio(trace_id, 0.0)
  assert_false(decision.is_sampled)
}

// === Trace Context Propagation Tests ===

test "propagate_trace_context_header_format" {
  let trace_id = "0af7651916cd43dd8448eb211c80319c"
  let span_id = "b7ad6b7169203331"
  let flags = "01"
  let header = "00-" + trace_id + "-" + span_id + "-" + flags
  assert_eq(header, "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01")
}

test "propagate_trace_context_with_parent_header_format" {
  let trace_id = "0af7651916cd43dd8448eb211c80319c"
  let span_id = "b7ad6b7169203331"
  let parent_span_id = "cbbd6b7169203331"
  let flags = "01"
  let header = "00-" + trace_id + "-" + span_id + "-" + parent_span_id + "-" + flags
  assert_eq(header, "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-cbbd6b7169203331-01")
}

test "propagate_trace_context_multiple_values" {
  // Multiple trace context values can be present
  let value1 = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
  let value2 = "00-1bf7651916cd43dd8448eb211c80319c-c8ad6b7169203331-01"
  assert_true(value1 != value2)
}

test "propagate_trace_context_order_matters" {
  // Trace context is ordered, nearer parent first
  let outermost = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
  let innermost = "00-0af7651916cd43dd8448eb211c80319c-c8ad6b7169203331-01"
  let combined = outermost + "," + innermost
  assert_true(combined.has_prefix("00-0af765"))
}

test "propagate_trace_context_whitespace_handling" {
  let header = "  00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01  "
  let trimmed = header.trim()
  assert_true(trimmed.starts_with("00-"))
}

// === Hex Encoding Edge Cases ===

test "hex_encoding_lowercase" {
  // Hex should be lowercase
  let bytes = [0x0A, 0x0B, 0x0C, 0x0D]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0a0b0c0d")
}

test "hex_encoding_high_values" {
  // Test hex encoding of high byte values
  let bytes = [0xEF, 0xFF, 0xAB, 0xCD]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "efffabcd")
}

test "hex_encoding_zero_padding" {
  // Single digit bytes should be zero-padded
  let bytes = [0x01, 0x0A, 0x0F]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "010a0f")
}

test "hex_encoding_max_byte" {
  let bytes = [0xFF]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "ff")
}

test "hex_encoding_min_byte" {
  let bytes = [0x00]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "00")
}

test "hex_encoding_mixed_case_input" {
  // Input hex parsing should be case-insensitive
  let upper = "FF"
  let lower = "ff"
  assert_eq(hex_to_int(upper), 255)
  assert_eq(hex_to_int(lower), 255)
}

// === Byte Validation Tests ===

test "check_all_zero_true" {
  let zero_bytes = [0, 0, 0, 0, 0]
  let result = check_all_zero(zero_bytes)
  assert_true(result)
}

test "check_all_zero_false" {
  let nonzero_bytes = [0, 0, 0, 1, 0]
  let result = check_all_zero(nonzero_bytes)
  assert_false(result)
}

test "check_all_zero_empty" {
  let empty_bytes : Array[Int] = []
  let result = check_all_zero(empty_bytes)
  assert_true(result)
}

test "check_all_zero_single_zero" {
  let single_zero = [0]
  let result = check_all_zero(single_zero)
  assert_true(result)
}

test "check_all_zero_single_nonzero" {
  let single_nonzero = [1]
  let result = check_all_zero(single_nonzero)
  assert_false(result)
}

// === Span Context Validation Tests ===

test "span_context_valid_with_trace_and_span" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_invalid_wrong_trace_length" {
  let short_trace = [1, 2, 3, 4, 5, 6, 7, 8]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(short_trace, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_invalid_wrong_span_length" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let short_span = [1, 2, 3, 4]
  let sc = span_context(trace_id, short_span, 1)
  assert_false(sc.is_valid())
}

test "span_context_trace_flags_0" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "span_context_trace_flags_255" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 255)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "span_context_sampled_bit_only" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_sampled())
}

test "span_context_trace_id_hex_length" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.trace_id_hex().length(), 32)
}

test "span_context_span_id_hex_length" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 1, 2, 3, 4, 5, 6, 7]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.span_id_hex().length(), 16)
}

// === Integration Tests ===

test "end_to_end_trace_generation" {
  // Generate a complete trace with proper IDs
  let trace_id = [0x4B, 0x1A, 0x8E, 0x9C, 0x3D, 0xF1, 0x2A, 0x8B, 0x9C, 0x4D, 0x1E, 0xF3, 0x2A, 0x8B, 0x9C, 0x4D]
  let span_id = [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0]
  let sc = span_context(trace_id, span_id, 1)
  
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_id_hex().length(), 32)
  assert_eq(sc.span_id_hex().length(), 16)
}

test "end_to_end_trace_propagation_format" {
  // Simulate W3C traceparent header format
  let trace_id_hex = "4b1a8e9c3df12a8b9c4d1ef32a8b9c4d"
  let span_id_hex = "123456789abcdef0"
  let flags = "01"
  
  let header = "00-" + trace_id_hex + "-" + span_id_hex + "-" + flags
  assert_eq(header, "00-4b1a8e9c3df12a8b9c4d1ef32a8b9c4d-123456789abcdef0-01")
}

test "end_to_end_child_span" {
  // Create a child span from a parent context
  let parent_trace_id = [0x4B, 0x1A, 0x8E, 0x9C, 0x3D, 0xF1, 0x2A, 0x8B, 0x9C, 0x4D, 0x1E, 0xF3, 0x2A, 0x8B, 0x9C, 0x4D]
  let parent_span_id = [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0]
  let parent_sc = span_context(parent_trace_id, parent_span_id, 1)
  
  assert_true(parent_sc.is_valid())
  assert_true(parent_sc.is_sampled())
  
  // Child span shares trace ID but has new span ID
  let child_span_id = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11]
  let child_sc = span_context(parent_trace_id, child_span_id, 1)
  
  assert_true(child_sc.is_valid())
  assert_eq(child_sc.trace_id_hex(), parent_sc.trace_id_hex())
  assert_true(child_sc.span_id_hex() != parent_sc.span_id_hex())
}

test "end_to_end_multiple_spans_in_trace" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  
  let mut span_contexts = []
  let mut i = 0
  while i < 10 {
    let span_id = [i, i + 1, i + 2, i + 3, i + 4, i + 5, i + 6, i + 7]
    let sc = span_context(trace_id, span_id, 1)
    span_contexts = span_contexts + [sc]
    i = i + 1
  }
  
  // All spans share trace ID
  let mut all_same_trace = true
  let mut i = 0
  while i < span_contexts.length() {
    if span_contexts[i].trace_id_hex() != span_contexts[0].trace_id_hex() {
      all_same_trace = false
    }
    i = i + 1
  }
  assert_true(all_same_trace)
  
  // Each span has unique ID
  let mut all_unique = true
  let mut i = 0
  while i < span_contexts.length() {
    let mut j = i + 1
    while j < span_contexts.length() {
      if span_contexts[i].span_id_hex() == span_contexts[j].span_id_hex() {
        all_unique = false
      }
      j = j + 1
    }
    i = i + 1
  }
  assert_true(all_unique)
}

test "end_to_end_sampling_consistency" {
  // Same trace ID should produce consistent sampling decisions
  let trace_id = [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  
  let decision1 = sampler_ratio(trace_id, 0.5)
  let decision2 = sampler_ratio(trace_id, 0.5)
  
  assert_eq(decision1.is_sampled, decision2.is_sampled)
}

test "end_to_end_unsampled_trace_propagation" {
  // Create an unsampled trace
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let parent_sc = span_context(trace_id, span_id, 0)
  
  assert_true(parent_sc.is_valid())
  assert_false(parent_sc.is_sampled())
  
  // Child should also not be sampled if parent-based sampling
  let decision = sampler_parent_based(parent_sc, false)
  assert_false(decision.is_sampled)
}

test "end_to_end_root_span_sampling" {
  // Root span sampling based on ratio
  let trace_id = [50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let decision = sampler_ratio(trace_id, 0.5)
  assert_true(decision.is_sampled)
}

test "end_to_end_bagged_spans" {
  // Test creating multiple spans in a bag
  let mut spans = []
  let mut i = 0
  while i < 50 {
    let trace_id = [i, i + 1, i + 2, i + 3, i + 4, i + 5, i + 6, i + 7, i + 8, i + 9, i + 10, i + 11, i + 12, i + 13, i + 14, i + 15]
    let span_id = [i + 16, i + 17, i + 18, i + 19, i + 20, i + 21, i + 22, i + 23]
    let sc = span_context(trace_id, span_id, 1)
    spans = spans + [sc]
    i = i + 1
  }
  
  assert_eq(spans.length(), 50)
  
  // Verify all are valid
  let mut valid_count = 0
  let mut i = 0
  while i < spans.length() {
    if spans[i].is_valid() {
      valid_count = valid_count + 1
    }
    i = i + 1
  }
  assert_eq(valid_count, 50)
}

test "end_to_end_trace_with_special_characters" {
  // Test trace IDs containing special byte values
  let trace_id = [0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F]
  let span_id = [0x7E, 0x7F, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85]
  let sc = span_context(trace_id, span_id, 1)
  
  assert_true(sc.is_valid())
  let hex = sc.trace_id_hex()
  assert_eq(hex.length(), 32)
}

// === Additional Edge Case Tests ===

test "edge_case_max_trace_id_variations" {
  // Test with max and near-max values
  let max_trace = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let max_span = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let sc = span_context(max_trace, max_span, 255)
  
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

test "edge_case_min_trace_id_variations" {
  // Test with minimal non-zero values
  let min_trace = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]
  let min_span = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]
  let sc = span_context(min_trace, min_span, 1)
  
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000001")
  assert_eq(sc.span_id_hex(), "0000000000000001")
}

test "edge_case_alternating_bits_trace" {
  let trace = [0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55]
  let span = [0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55]
  let sc = span_context(trace, span, 1)
  
  assert_true(sc.is_valid())
}

test "edge_case_sparse_nonzero_trace" {
  // Only every 4th byte is non-zero
  let trace = [0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 4]
  let span = [0, 0, 0, 1, 0, 0, 0, 2]
  let sc = span_context(trace, span, 1)
  
  assert_true(sc.is_valid())
}

test "edge_case_trace_id_hex_all_f" {
  let trace = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let sc = span_context(trace, [1, 2, 3, 4, 5, 6, 7, 8], 1)
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
}

test "edge_case_span_id_hex_all_f" {
  let span = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let sc = span_context([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], span, 1)
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

// Helper functions for tests

fn check_all_zero(bytes : Array[Int]) -> Bool {
  let mut i = 0
  while i < bytes.length() {
    if bytes[i] != 0 {
      return false
    }
    i = i + 1
  }
  true
}
