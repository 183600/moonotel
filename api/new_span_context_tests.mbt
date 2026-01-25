// Additional SpanContext test scenarios for comprehensive coverage

// Tests for hexadecimal encoding consistency

test "trace_id_hex_lowercase_consistency" {
  let trace_id = [10, 11, 12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc = span_context(trace_id, span_id, 1)
  let hex_str = sc.trace_id_hex()
  
  assert_eq(hex_str.length(), 32)
  // Ensure lowercase hex values
  assert_true(hex_str.contains("0a"))
  assert_true(hex_str.contains("0b"))
  assert_true(hex_str.contains("0c"))
  assert_true(hex_str.contains("0d"))
  assert_true(hex_str.contains("0e"))
  assert_true(hex_str.contains("0f"))
}

test "span_id_hex_with_zero_values" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  
  let sc = span_context(trace_id, span_id, 1)
  let hex_str = sc.span_id_hex()
  
  assert_eq(hex_str.length(), 16)
  assert_eq(hex_str, "0000000000000001")
}

test "invalid_trace_zero_trace_id_detected" {
  let zero_trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc = span_context(zero_trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "invalid_trace_zero_span_id_detected" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let zero_span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  
  let sc = span_context(trace_id, zero_span_id, 1)
  assert_false(sc.is_valid())
}

test "trace_id_with_max_byte_values" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  
  let hex_str = sc.trace_id_hex()
  assert_eq(hex_str, "ffffffffffffffffffffffffffffffff")
}

test "trace_flags_multiple_bits_pattern" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  // Test sampled flag (bit 0 = 1)
  let sc1 = span_context(trace_id, span_id, 1)
  assert_true(sc1.is_sampled())
  
  // Test flag 2 (bit 1 = 1, bit 0 = 0)
  let sc2 = span_context(trace_id, span_id, 2)
  assert_false(sc2.is_sampled())
  
  // Test flags 1 and 2 together (bits 0 and 1 = 1)
  let sc3 = span_context(trace_id, span_id, 3)
  assert_true(sc3.is_sampled())
  
  // Test with higher bits
  let sc4 = span_context(trace_id, span_id, 5)
  assert_true(sc4.is_sampled())
  
  let sc5 = span_context(trace_id, span_id, 8)
  assert_false(sc5.is_sampled())
}

test "invalid_span_context_properties" {
  let sc = invalid_span_context()
  assert_false(sc.is_sampled())
  assert_false(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
}

test "hex_encoding_all_byte_boundary_values" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let hex_str = bytes_to_hex(bytes)
  
  assert_eq(hex_str, "000102030405060708090a0b0c0d0e0f")
}

test "hex_encoding_high_nibble_values" {
  let bytes = [160, 175, 190, 205, 220, 239, 254, 128]
  let hex_str = bytes_to_hex(bytes)
  
  assert_eq(hex_str, "a0afbecddceffe80")
}

test "byte_to_hex_char_complete_range" {
  assert_eq(byte_to_hex_char(0), "0")
  assert_eq(byte_to_hex_char(5), "5")
  assert_eq(byte_to_hex_char(9), "9")
  assert_eq(byte_to_hex_char(10), "a")
  assert_eq(byte_to_hex_char(11), "b")
  assert_eq(byte_to_hex_char(12), "c")
  assert_eq(byte_to_hex_char(13), "d")
  assert_eq(byte_to_hex_char(14), "e")
  assert_eq(byte_to_hex_char(15), "f")
}

test "is_zero_detects_single_non_zero" {
  let non_zero = [0, 0, 0, 0, 0, 0, 0, 1]
  assert_false(is_zero(non_zero))
}

test "is_zero_all_zeros_array" {
  let all_zeros = [0, 0, 0, 0, 0, 0, 0, 0]
  assert_true(is_zero(all_zeros))
}

test "is_zero_large_zero_array" {
  let large_zeros = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_true(is_zero(large_zeros))
}

test "is_zero_detects_later_nonzero" {
  let later_nonzero = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5]
  assert_false(is_zero(later_nonzero))
}

test "span_context_immutability_verification" {
  let trace_id1 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id1 = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let trace_id2 = [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  let span_id2 = [8, 7, 6, 5, 4, 3, 2, 1]
  
  let sc1 = span_context(trace_id1, span_id1, 1)
  let sc2 = span_context(trace_id2, span_id2, 0)
  
  // Verify they remain distinct objects
  assert_true(sc1.trace_id_hex() != sc2.trace_id_hex())
  assert_true(sc1.span_id_hex() != sc2.span_id_hex())
  assert_true(sc1.is_sampled())
  assert_false(sc2.is_sampled())
}

test "span_context_trace_id_length_enforced" {
  let valid_trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let short_trace_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let valid_sc = span_context(valid_trace_id, span_id, 1)
  let invalid_sc = span_context(short_trace_id, span_id, 1)
  
  assert_true(valid_sc.is_valid())
  assert_false(invalid_sc.is_valid())
}

test "span_context_span_id_length_enforced" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let valid_span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let short_span_id = [1, 2, 3, 4]
  
  let valid_sc = span_context(trace_id, valid_span_id, 1)
  let invalid_sc = span_context(trace_id, short_span_id, 1)
  
  assert_true(valid_sc.is_valid())
  assert_false(invalid_sc.is_valid())
}

test "hex_encoding_empty_array" {
  let empty : Array[Int] = []
  let hex_str = bytes_to_hex(empty)
  
  assert_eq(hex_str, "")
}

test "invalid_then_valid_context_transition" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let zero_trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  
  // Create invalid context first
  let sc_invalid = span_context(zero_trace_id, span_id, 1)
  assert_false(sc_invalid.is_valid())
  
  // Then create valid context
  let sc_valid = span_context(trace_id, span_id, 1)
  assert_true(sc_valid.is_valid())
  
  // Verify the invalid one wasn't modified
  assert_false(sc_invalid.is_valid())
}

test "trace_id_hex_consistent_output" {
  let trace_id = [11, 22, 33, 44, 55, 66, 77, 88, 99, 110, 121, 132, 143, 154, 165, 176]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc1 = span_context(trace_id, span_id, 1)
  let hex1 = sc1.trace_id_hex()
  
  let sc2 = span_context(trace_id, span_id, 1)
  let hex2 = sc2.trace_id_hex()
  
  // Same input should produce same output
  assert_eq(hex1, hex2)
}
