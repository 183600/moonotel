// Additional test coverage for OpenTelemetry tracing SDK

// Tests for span_context edge cases
test "span_context_with_max_trace_id" {
  let trace_id = Array::make(16, 255)
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
  assert_true(context.is_sampled())
}

test "span_context_with_max_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = Array::make(8, 255)
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_context_zero_trace_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 0)
  assert_true(context.is_valid())
  assert_false(context.is_sampled())
}

test "span_context_odd_trace_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 3)
  assert_true(context.is_sampled())
}

test "span_context_even_trace_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 2)
  assert_false(context.is_sampled())
}

test "span_context_large_trace_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 255)
  assert_true(context.is_sampled())
}

// Tests for hex encoding edge cases
test "hex_encoding_all_zeros_trace_id" {
  let trace_id = Array::make(16, 0)
  let hex = bytes_to_hex(trace_id)
  assert_eq(hex, "00000000000000000000000000000000")
}

test "hex_encoding_all_ones" {
  let bytes = [1, 1, 1, 1]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "01010101")
}

test "hex_encoding_all_max" {
  let bytes = [255, 255, 255, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "ffffffff")
}

test "hex_encoding_mixed_values" {
  let bytes = [0, 15, 16, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "000f10ff")
}

test "hex_encoding_sequential" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "000102030405060708090a0b0c0d0e0f")
}

test "hex_encoding_alternating_pattern" {
  let bytes = [170, 85, 170, 85]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "aa55aa55")
}

// Tests for is_zero function
test "is_zero_empty_array" {
  let bytes : Array[Int] = []
  assert_true(is_zero(bytes))
}

test "is_zero_single_zero" {
  let bytes = [0]
  assert_true(is_zero(bytes))
}

test "is_zero_single_nonzero" {
  let bytes = [1]
  assert_false(is_zero(bytes))
}

test "is_zero_multiple_zeros" {
  let bytes = [0, 0, 0, 0]
  assert_true(is_zero(bytes))
}

test "is_zero_first_nonzero" {
  let bytes = [1, 0, 0, 0]
  assert_false(is_zero(bytes))
}

test "is_zero_last_nonzero" {
  let bytes = [0, 0, 0, 1]
  assert_false(is_zero(bytes))
}

test "is_zero_middle_nonzero" {
  let bytes = [0, 1, 0, 0]
  assert_false(is_zero(bytes))
}

// Tests for invalid_span_context
test "invalid_span_context_properties" {
  let context = invalid_span_context()
  assert_false(context.is_valid())
  assert_false(context.is_sampled())
}

test "invalid_span_context_trace_id_length" {
  let context = invalid_span_context()
  assert_eq(context.trace_id_hex().length(), 32)
}

test "invalid_span_context_span_id_length" {
  let context = invalid_span_context()
  assert_eq(context.span_id_hex().length(), 16)
}

test "invalid_span_context_all_zeros" {
  let context = invalid_span_context()
  assert_eq(context.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(context.span_id_hex(), "0000000000000000")
}

// Tests for span_context validation
test "span_context_invalid_short_trace_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_invalid_long_trace_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_invalid_short_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_invalid_long_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8, 9]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_invalid_zero_trace_id" {
  let trace_id = Array::make(16, 0)
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_invalid_zero_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = Array::make(8, 0)
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_invalid_both_zero" {
  let trace_id = Array::make(16, 0)
  let span_id = Array::make(8, 0)
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

// Tests for byte_to_hex_char function
test "byte_to_hex_char_0" {
  assert_eq(byte_to_hex_char(0), "0")
}

test "byte_to_hex_char_1" {
  assert_eq(byte_to_hex_char(1), "1")
}

test "byte_to_hex_char_9" {
  assert_eq(byte_to_hex_char(9), "9")
}

test "byte_to_hex_char_10_a" {
  assert_eq(byte_to_hex_char(10), "a")
}

test "byte_to_hex_char_15_f" {
  assert_eq(byte_to_hex_char(15), "f")
}

test "byte_to_hex_char_invalid_negative" {
  assert_eq(byte_to_hex_char(-1), "0")
}

test "byte_to_hex_char_invalid_large" {
  assert_eq(byte_to_hex_char(16), "0")
}

// Tests for hex format consistency
test "hex_format_lowercase" {
  let bytes = [10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0a0b0c0d0e0f")
}

test "hex_format_no_uppercase" {
  let bytes = [10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(bytes)
  assert_false(hex.contains("A"))
  assert_false(hex.contains("B"))
  assert_false(hex.contains("C"))
  assert_false(hex.contains("D"))
  assert_false(hex.contains("E"))
  assert_false(hex.contains("F"))
}

// Tests for trace_flags bit manipulation
test "trace_flags_bit_0_set" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_sampled())
}

test "trace_flags_bit_0_clear" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 0)
  assert_false(context.is_sampled())
}

test "trace_flags_multiple_bits" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 7)
  assert_true(context.is_sampled())
}

test "trace_flags_128" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 128)
  assert_false(context.is_sampled())
}

// Tests for boundary conditions
test "boundary_single_bit_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "boundary_single_bit_span_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "boundary_first_byte_nonzero_trace_id" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "boundary_last_byte_nonzero_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

// Tests for hex encoding length
test "hex_length_trace_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_eq(context.trace_id_hex().length(), 32)
}

test "hex_length_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_eq(context.span_id_hex().length(), 16)
}

// Tests for specific hex patterns
test "hex_pattern_aa" {
  let bytes = [170]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "aa")
}

test "hex_pattern_55" {
  let bytes = [85]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "55")
}

test "hex_pattern_ff" {
  let bytes = [255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "ff")
}

test "hex_pattern_01" {
  let bytes = [1]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "01")
}

// Tests for array operations
test "is_zero_large_array" {
  let bytes = Array::make(100, 0)
  assert_true(is_zero(bytes))
}

test "is_zero_large_array_with_one_nonzero" {
  let bytes = Array::make(100, 0)
  bytes[50] = 1
  assert_false(is_zero(bytes))
}

// Tests for context comparison
test "contexts_with_same_ids_are_equal" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context1 = span_context(trace_id, span_id, 1)
  let context2 = span_context(trace_id, span_id, 1)
  assert_eq(context1.trace_id_hex(), context2.trace_id_hex())
  assert_eq(context1.span_id_hex(), context2.span_id_hex())
}

test "contexts_with_different_trace_ids" {
  let trace_id1 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let trace_id2 = [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context1 = span_context(trace_id1, span_id, 1)
  let context2 = span_context(trace_id2, span_id, 1)
  assert_true(context1.trace_id_hex() != context2.trace_id_hex())
}

test "contexts_with_different_span_ids" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id1 = [1, 2, 3, 4, 5, 6, 7, 8]
  let span_id2 = [8, 7, 6, 5, 4, 3, 2, 1]
  let context1 = span_context(trace_id, span_id1, 1)
  let context2 = span_context(trace_id, span_id2, 1)
  assert_true(context1.span_id_hex() != context2.span_id_hex())
}

// Tests for special byte values
test "byte_value_127" {
  let bytes = [127]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "7f")
}

test "byte_value_128" {
  let bytes = [128]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "80")
}

test "byte_value_254" {
  let bytes = [254]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "fe")
}

// Tests for context state consistency
test "valid_context_remains_valid" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
  assert_true(context.is_valid())
}

test "invalid_context_remains_invalid" {
  let context = invalid_span_context()
  assert_false(context.is_valid())
  assert_false(context.is_valid())
}

// Tests for sampling consistency
test "sampled_context_remains_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_sampled())
  assert_true(context.is_sampled())
}

test "unsampled_context_remains_unsampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 0)
  assert_false(context.is_sampled())
  assert_false(context.is_sampled())
}

// Tests for hex conversion consistency
test "hex_conversion_consistency" {
  let bytes = [1, 35, 69, 103, 137, 171, 205, 239]
  let hex1 = bytes_to_hex(bytes)
  let hex2 = bytes_to_hex(bytes)
  assert_eq(hex1, hex2)
}

test "hex_conversion_specific_values" {
  let bytes = [16, 32, 48, 64, 80, 96, 112, 128]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "1020304050607080")
}
