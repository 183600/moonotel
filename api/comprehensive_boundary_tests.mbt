// Comprehensive boundary and edge case tests

// Tests for bit patterns in trace IDs
test "trace_id_pattern_all_bits_set" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
  assert_eq(context.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
}

test "span_id_pattern_all_bits_set" {
  let trace_id = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let context = span_context(trace_id, span_id, 1)
  assert_eq(context.span_id_hex(), "ffffffffffffffff")
}

test "trace_id_alternating_bits" {
  let trace_id = [170, 170, 170, 170, 170, 170, 170, 170, 85, 85, 85, 85, 85, 85, 85, 85]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_alternating_bits" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [170, 85, 170, 85, 170, 85, 170, 85]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

// Tests for specific byte values in each position
test "trace_id_first_byte_max" {
  let trace_id = [255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_last_byte_max" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_first_byte_max" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [255, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_last_byte_max" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 255]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

// Tests for trace_flags edge values
test "trace_flags_value_1" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_sampled())
}

test "trace_flags_value_2" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 2)
  assert_false(context.is_sampled())
}

test "trace_flags_value_4" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 4)
  assert_false(context.is_sampled())
}

test "trace_flags_value_8" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 8)
  assert_false(context.is_sampled())
}

test "trace_flags_value_16" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 16)
  assert_false(context.is_sampled())
}

test "trace_flags_value_31" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 31)
  assert_true(context.is_sampled())
}

test "trace_flags_value_63" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 63)
  assert_true(context.is_sampled())
}

test "trace_flags_value_127" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 127)
  assert_true(context.is_sampled())
}

test "trace_flags_value_129" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 129)
  assert_true(context.is_sampled())
}

// Tests for hex encoding with various patterns
test "hex_pattern_ascending" {
  let bytes = [0, 16, 32, 48, 64, 80, 96, 112]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0010203040506070")
}

test "hex_pattern_descending" {
  let bytes = [240, 224, 208, 192, 176, 160, 144, 128]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "f0e0d0c0b0a09080")
}

test "hex_pattern_powers_of_two" {
  let bytes = [1, 2, 4, 8, 16, 32, 64, 128]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0102040810204080")
}

test "hex_pattern_nibbles_ascending" {
  let bytes = [17, 34, 51, 68, 85, 102, 119, 136]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "1122334455667788")
}

test "hex_single_nibble_high" {
  let bytes = [16, 32, 48, 64]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "10203040")
}

test "hex_single_nibble_low" {
  let bytes = [1, 2, 3, 4]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "01020304")
}

// Tests for is_zero with patterns
test "is_zero_single_value_at_start" {
  let bytes = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_false(is_zero(bytes))
}

test "is_zero_single_value_at_end" {
  let bytes = [0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  assert_false(is_zero(bytes))
}

test "is_zero_two_values" {
  let bytes = [1, 0, 0, 0, 1, 0, 0, 0]
  assert_false(is_zero(bytes))
}

test "is_zero_alternating_with_zeros" {
  let bytes = [1, 0, 1, 0, 1, 0, 1, 0]
  assert_false(is_zero(bytes))
}

// Tests for context validation with edge case IDs
test "valid_context_minimal_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 0)
  assert_true(context.is_valid())
  assert_false(context.is_sampled())
}

test "valid_context_maximal_trace_id" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let context = span_context(trace_id, span_id, 255)
  assert_true(context.is_valid())
  assert_true(context.is_sampled())
}

// Tests for hex conversion with specific byte ranges
test "hex_bytes_0_to_15" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex.length(), 32)
}

test "hex_bytes_16_to_31" {
  let bytes = [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex.length(), 32)
}

test "hex_bytes_240_to_255" {
  let bytes = [240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
}

// Tests for byte_to_hex_char with all valid values
test "byte_to_hex_char_2" {
  assert_eq(byte_to_hex_char(2), "2")
}

test "byte_to_hex_char_3" {
  assert_eq(byte_to_hex_char(3), "3")
}

test "byte_to_hex_char_4" {
  assert_eq(byte_to_hex_char(4), "4")
}

test "byte_to_hex_char_5" {
  assert_eq(byte_to_hex_char(5), "5")
}

test "byte_to_hex_char_6" {
  assert_eq(byte_to_hex_char(6), "6")
}

test "byte_to_hex_char_7" {
  assert_eq(byte_to_hex_char(7), "7")
}

test "byte_to_hex_char_8" {
  assert_eq(byte_to_hex_char(8), "8")
}

test "byte_to_hex_char_11_b" {
  assert_eq(byte_to_hex_char(11), "b")
}

test "byte_to_hex_char_12_c" {
  assert_eq(byte_to_hex_char(12), "c")
}

test "byte_to_hex_char_13_d" {
  assert_eq(byte_to_hex_char(13), "d")
}

test "byte_to_hex_char_14_e" {
  assert_eq(byte_to_hex_char(14), "e")
}

// Tests for various invalid contexts
test "invalid_context_empty_trace_id" {
  let trace_id : Array[Int] = []
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "invalid_context_empty_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id : Array[Int] = []
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "invalid_context_both_empty" {
  let trace_id : Array[Int] = []
  let span_id : Array[Int] = []
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

// Tests for trace ID hex format
test "trace_id_hex_format_length_32" {
  let trace_id = [100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100]
  let span_id = [50, 50, 50, 50, 50, 50, 50, 50]
  let context = span_context(trace_id, span_id, 1)
  assert_eq(context.trace_id_hex().length(), 32)
}

test "span_id_hex_format_length_16" {
  let trace_id = [100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100]
  let span_id = [50, 50, 50, 50, 50, 50, 50, 50]
  let context = span_context(trace_id, span_id, 1)
  assert_eq(context.span_id_hex().length(), 16)
}

// Tests for sampling with various flags
test "sampling_with_flag_5" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 5)
  assert_true(context.is_sampled())
}

test "sampling_with_flag_9" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 9)
  assert_true(context.is_sampled())
}

test "sampling_with_flag_15" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 15)
  assert_true(context.is_sampled())
}

test "sampling_with_flag_64" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 64)
  assert_false(context.is_sampled())
}

test "sampling_with_flag_200" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 200)
  assert_false(context.is_sampled())
}

// Tests for specific hex patterns
test "hex_pattern_repeated_aa" {
  let bytes = [170, 170, 170, 170]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "aaaaaaaa")
}

test "hex_pattern_repeated_55" {
  let bytes = [85, 85, 85, 85]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "55555555")
}

test "hex_pattern_repeated_ff" {
  let bytes = [255, 255, 255, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "ffffffff")
}

test "hex_pattern_repeated_00" {
  let bytes = [0, 0, 0, 0]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "00000000")
}

// Tests for context properties consistency
test "context_validity_check_multiple_calls" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [11, 22, 33, 44, 55, 66, 77, 88]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
  assert_true(context.is_valid())
  assert_true(context.is_valid())
}

test "context_sampling_check_multiple_calls" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [11, 22, 33, 44, 55, 66, 77, 88]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_sampled())
  assert_true(context.is_sampled())
  assert_true(context.is_sampled())
}

// Tests for hex conversion with edge bytes
test "hex_byte_value_17" {
  let bytes = [17]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "11")
}

test "hex_byte_value_34" {
  let bytes = [34]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "22")
}

test "hex_byte_value_51" {
  let bytes = [51]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "33")
}

test "hex_byte_value_68" {
  let bytes = [68]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "44")
}

test "hex_byte_value_85" {
  let bytes = [85]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "55")
}

test "hex_byte_value_102" {
  let bytes = [102]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "66")
}

test "hex_byte_value_119" {
  let bytes = [119]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "77")
}

test "hex_byte_value_136" {
  let bytes = [136]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "88")
}

test "hex_byte_value_153" {
  let bytes = [153]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "99")
}

test "hex_byte_value_170" {
  let bytes = [170]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "aa")
}

test "hex_byte_value_187" {
  let bytes = [187]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "bb")
}

test "hex_byte_value_204" {
  let bytes = [204]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "cc")
}

test "hex_byte_value_221" {
  let bytes = [221]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "dd")
}

test "hex_byte_value_238" {
  let bytes = [238]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "ee")
}

// Tests for is_zero with specific patterns
test "is_zero_trace_id_size" {
  let bytes = Array::make(16, 0)
  assert_true(is_zero(bytes))
}

test "is_zero_span_id_size" {
  let bytes = Array::make(8, 0)
  assert_true(is_zero(bytes))
}

test "is_zero_with_value_at_position_7" {
  let bytes = [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_false(is_zero(bytes))
}

test "is_zero_with_value_at_position_8" {
  let bytes = [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0]
  assert_false(is_zero(bytes))
}

// Tests for context with different ID combinations
test "context_sequential_trace_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [8, 7, 6, 5, 4, 3, 2, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "context_reverse_sequential_trace_id" {
  let trace_id = [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "context_with_prime_numbers_trace_id" {
  let trace_id = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53]
  let span_id = [2, 3, 5, 7, 11, 13, 17, 19]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

// Tests for hex encoding with mixed patterns
test "hex_mixed_pattern_1" {
  let bytes = [15, 240, 15, 240]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0ff00ff0")
}

test "hex_mixed_pattern_2" {
  let bytes = [170, 85, 255, 0]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "aa55ff00")
}

test "hex_mixed_pattern_3" {
  let bytes = [128, 64, 32, 16]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "80402010")
}
