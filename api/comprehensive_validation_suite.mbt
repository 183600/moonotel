// Comprehensive validation test suite
// Tests for SpanContext with extensive coverage

// === Trace ID Boundary Tests ===

test "trace_id_single_bit_position_0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "01000000000000000000000000000000")
}

test "trace_id_single_bit_position_5" {
  let trace_id = [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000100000000000000000000")
}

test "trace_id_single_bit_position_10" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000010000000000")
}

test "trace_id_single_bit_position_15" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000001")
}

// === Span ID Boundary Tests ===

test "span_id_single_bit_position_0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0100000000000000")
}

test "span_id_single_bit_position_3" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 1, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0000000100000000")
}

test "span_id_single_bit_position_7" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0000000000000001")
}

// === Hex Encoding Edge Cases ===

test "hex_encoding_nibble_boundary_0x0f" {
  let bytes = [0x0F]
  assert_eq(bytes_to_hex(bytes), "0f")
}

test "hex_encoding_nibble_boundary_0x10" {
  let bytes = [0x10]
  assert_eq(bytes_to_hex(bytes), "10")
}

test "hex_encoding_nibble_boundary_0xf0" {
  let bytes = [0xF0]
  assert_eq(bytes_to_hex(bytes), "f0")
}

test "hex_encoding_consecutive_values" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  assert_eq(bytes_to_hex(bytes), "000102030405060708090a0b0c0d0e0f")
}

test "hex_encoding_reverse_consecutive" {
  let bytes = [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  assert_eq(bytes_to_hex(bytes), "0f0e0d0c0b0a09080706050403020100")
}

// === Trace Flags Tests ===

test "trace_flags_value_0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 0)
}

test "trace_flags_value_1" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 1)
}

test "trace_flags_value_2" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 2)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 2)
}

test "trace_flags_value_3" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 3)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 3)
}

test "trace_flags_value_4" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 4)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 4)
}

test "trace_flags_value_5" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 5)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 5)
}

test "trace_flags_value_128" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 128)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 128)
}

test "trace_flags_value_129" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 129)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 129)
}

// === Pattern Tests ===

test "pattern_checkerboard_trace_id" {
  let trace_id = [170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "aa55aa55aa55aa55aa55aa55aa55aa55")
}

test "pattern_reverse_checkerboard_trace_id" {
  let trace_id = [85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "55aa55aa55aa55aa55aa55aa55aa55aa")
}

test "pattern_ascending_span_id" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0102030405060708")
}

test "pattern_descending_span_id" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [8, 7, 6, 5, 4, 3, 2, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0807060504030201")
}

// === Validation Tests for Invalid Contexts ===

test "invalid_empty_trace_id" {
  let trace_id : Array[Int] = []
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "invalid_empty_span_id" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id : Array[Int] = []
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "invalid_both_empty" {
  let trace_id : Array[Int] = []
  let span_id : Array[Int] = []
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "invalid_trace_id_too_short_1" {
  let trace_id = [1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "invalid_trace_id_too_short_15" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "invalid_span_id_too_short_1" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "invalid_span_id_too_short_7" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

// === Helper Function Tests ===

test "is_zero_empty_array" {
  let arr : Array[Int] = []
  assert_true(is_zero(arr))
}

test "is_zero_single_zero" {
  let arr = [0]
  assert_true(is_zero(arr))
}

test "is_zero_single_nonzero" {
  let arr = [1]
  assert_false(is_zero(arr))
}

test "is_zero_two_zeros" {
  let arr = [0, 0]
  assert_true(is_zero(arr))
}

test "is_zero_first_nonzero" {
  let arr = [1, 0, 0, 0]
  assert_false(is_zero(arr))
}

test "is_zero_middle_nonzero" {
  let arr = [0, 0, 1, 0, 0]
  assert_false(is_zero(arr))
}

test "is_zero_last_nonzero" {
  let arr = [0, 0, 0, 1]
  assert_false(is_zero(arr))
}

test "bytes_to_hex_empty" {
  let bytes : Array[Int] = []
  assert_eq(bytes_to_hex(bytes), "")
}

test "bytes_to_hex_single_0" {
  let bytes = [0]
  assert_eq(bytes_to_hex(bytes), "00")
}

test "bytes_to_hex_single_255" {
  let bytes = [255]
  assert_eq(bytes_to_hex(bytes), "ff")
}

test "bytes_to_hex_two_bytes" {
  let bytes = [0xAB, 0xCD]
  assert_eq(bytes_to_hex(bytes), "abcd")
}

test "bytes_to_hex_power_of_2" {
  let bytes = [1, 2, 4, 8, 16, 32, 64, 128]
  assert_eq(bytes_to_hex(bytes), "0102040810204080")
}

// === Complex Validation Scenarios ===

test "valid_context_random_1" {
  let trace_id = [17, 34, 51, 68, 85, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255, 16]
  let span_id = [32, 48, 64, 80, 96, 112, 128, 144]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "valid_context_random_2" {
  let trace_id = [99, 88, 77, 66, 55, 44, 33, 22, 11, 101, 121, 141, 161, 181, 201, 221]
  let span_id = [111, 122, 133, 144, 155, 166, 177, 188]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "valid_context_fibonacci_like" {
  let trace_id = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 121, 98, 219]
  let span_id = [1, 2, 3, 5, 8, 13, 21, 34]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "valid_context_prime_numbers" {
  let trace_id = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53]
  let span_id = [59, 61, 67, 71, 73, 79, 83, 89]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

// === Byte Value Edge Cases ===

test "byte_value_0x7F" {
  let bytes = [0x7F]
  assert_eq(bytes_to_hex(bytes), "7f")
}

test "byte_value_0x80" {
  let bytes = [0x80]
  assert_eq(bytes_to_hex(bytes), "80")
}

test "byte_value_0xFF" {
  let bytes = [0xFF]
  assert_eq(bytes_to_hex(bytes), "ff")
}

test "byte_values_boundaries" {
  let bytes = [0, 1, 126, 127, 128, 129, 254, 255]
  assert_eq(bytes_to_hex(bytes), "00017e7f8081feff")
}

// === Trace Context Combinations ===

test "max_trace_min_span" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc.span_id_hex(), "0100000000000000")
}

test "min_trace_max_span" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "01000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

test "half_max_values" {
  let trace_id = [127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127]
  let span_id = [127, 127, 127, 127, 127, 127, 127, 127]
  let sc = span_context(trace_id, span_id, 127)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

// === Invalid Span Context Tests ===

test "invalid_span_context_properties" {
  let sc = invalid_span_context()
  assert_false(sc.is_valid())
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 0)
}

test "invalid_span_context_hex_all_zeros" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
}

test "invalid_span_context_trace_id_length" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_id.length(), 16)
}

test "invalid_span_context_span_id_length" {
  let sc = invalid_span_context()
  assert_eq(sc.span_id.length(), 8)
}

// === Symmetry Tests ===

test "symmetry_same_ids_different_flags_1" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc1 = span_context(trace_id, span_id, 0)
  let sc2 = span_context(trace_id, span_id, 1)
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
  assert_eq(sc1.span_id_hex(), sc2.span_id_hex())
  assert_false(sc1.is_sampled())
  assert_true(sc2.is_sampled())
}

test "symmetry_same_ids_different_flags_2" {
  let trace_id = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]
  let span_id = [10, 20, 30, 40, 50, 60, 70, 80]
  let sc1 = span_context(trace_id, span_id, 2)
  let sc2 = span_context(trace_id, span_id, 3)
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
  assert_eq(sc1.span_id_hex(), sc2.span_id_hex())
  assert_false(sc1.is_sampled())
  assert_true(sc2.is_sampled())
}

// === Bit Pattern Tests ===

test "bit_pattern_all_ones_high_nibble" {
  let bytes = [0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7]
  assert_eq(bytes_to_hex(bytes), "f0f1f2f3f4f5f6f7")
}

test "bit_pattern_all_ones_low_nibble" {
  let bytes = [0x0F, 0x1F, 0x2F, 0x3F, 0x4F, 0x5F, 0x6F, 0x7F]
  assert_eq(bytes_to_hex(bytes), "0f1f2f3f4f5f6f7f")
}

test "bit_pattern_alternating_nibbles" {
  let bytes = [0xA5, 0x5A, 0xA5, 0x5A]
  assert_eq(bytes_to_hex(bytes), "a55aa55a")
}

// === Multi-byte Patterns ===

test "multibyte_palindrome_trace" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 8, 7, 6, 5, 4, 3, 2, 1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "01020304050607080807060504030201")
}

test "multibyte_palindrome_span" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 4, 3, 2, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0102030404030201")
}

// === Sampling Flag Comprehensive Tests ===

test "sampling_flag_powers_of_2_bit0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_sampled())
}

test "sampling_flag_powers_of_2_bit1" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 2)
  assert_false(sc.is_sampled())
}

test "sampling_flag_powers_of_2_bit2" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 4)
  assert_false(sc.is_sampled())
}

test "sampling_flag_powers_of_2_bit3" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 8)
  assert_false(sc.is_sampled())
}

test "sampling_flag_powers_of_2_bit7" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 128)
  assert_false(sc.is_sampled())
}

test "sampling_flag_combined_bits_0_1" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 3)
  assert_true(sc.is_sampled())
}

test "sampling_flag_combined_bits_1_2" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 6)
  assert_false(sc.is_sampled())
}

test "sampling_flag_combined_bits_all" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 255)
  assert_true(sc.is_sampled())
}

// === Additional Hex Encoding Tests ===

test "hex_encoding_double_digit_values" {
  let bytes = [10, 11, 12, 13, 14, 15]
  assert_eq(bytes_to_hex(bytes), "0a0b0c0d0e0f")
}

test "hex_encoding_triple_digit_values" {
  let bytes = [100, 101, 102, 200, 201, 202]
  assert_eq(bytes_to_hex(bytes), "646566c8c9ca")
}

test "hex_encoding_mixed_ranges" {
  let bytes = [5, 50, 150, 250]
  assert_eq(bytes_to_hex(bytes), "053296fa")
}

// === Zero Detection Edge Cases ===

test "is_zero_three_zeros" {
  let arr = [0, 0, 0]
  assert_true(is_zero(arr))
}

test "is_zero_sixteen_zeros" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_true(is_zero(arr))
}

test "is_zero_mixed_with_first_nonzero" {
  let arr = [255, 0, 0, 0]
  assert_false(is_zero(arr))
}

test "is_zero_mixed_with_last_nonzero" {
  let arr = [0, 0, 0, 255]
  assert_false(is_zero(arr))
}

// === Context Creation Variations ===

test "context_with_sequential_bytes" {
  let trace_id = [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
  let span_id = [32, 33, 34, 35, 36, 37, 38, 39]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "101112131415161718191a1b1c1d1e1f")
  assert_eq(sc.span_id_hex(), "2021222324252627")
}

test "context_with_high_values" {
  let trace_id = [240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255]
  let span_id = [240, 241, 242, 243, 244, 245, 246, 247]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
  assert_eq(sc.span_id_hex(), "f0f1f2f3f4f5f6f7")
}

// === Boundary Validation Tests ===

test "trace_id_length_17_invalid" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_id_length_9_invalid" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8, 9]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

// === Specific Byte Position Tests ===

test "trace_id_byte_2_max" {
  let trace_id = [0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "0000ff00000000000000000000000000")
}

test "trace_id_byte_7_max" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000ff0000000000000000")
}

test "span_id_byte_2_max" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 255, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0000ff0000000000")
}

test "span_id_byte_5_max" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 255, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0000000000ff0000")
}

// === Repeating Pattern Variations ===

test "repeating_byte_value_1" {
  let trace_id = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  let span_id = [1, 1, 1, 1, 1, 1, 1, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "01010101010101010101010101010101")
  assert_eq(sc.span_id_hex(), "0101010101010101")
}

test "repeating_byte_value_17" {
  let trace_id = [17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17]
  let span_id = [17, 17, 17, 17, 17, 17, 17, 17]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "11111111111111111111111111111111")
  assert_eq(sc.span_id_hex(), "1111111111111111")
}

test "repeating_byte_value_68" {
  let trace_id = [68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68]
  let span_id = [68, 68, 68, 68, 68, 68, 68, 68]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "44444444444444444444444444444444")
  assert_eq(sc.span_id_hex(), "4444444444444444")
}

test "repeating_byte_value_204" {
  let trace_id = [204, 204, 204, 204, 204, 204, 204, 204, 204, 204, 204, 204, 204, 204, 204, 204]
  let span_id = [204, 204, 204, 204, 204, 204, 204, 204]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "cccccccccccccccccccccccccccccccc")
  assert_eq(sc.span_id_hex(), "cccccccccccccccc")
}

// === Alternating Pattern Tests ===

test "alternating_0_255_trace" {
  let trace_id = [0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00ff00ff00ff00ff00ff00ff00ff00ff")
}

test "alternating_255_0_trace" {
  let trace_id = [255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "ff00ff00ff00ff00ff00ff00ff00ff00")
}

test "alternating_1_2_span" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 1, 2, 1, 2, 1, 2]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0102010201020102")
}

// === Flag Boundary Tests ===

test "trace_flags_63" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 63)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 63)
}

test "trace_flags_64" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 64)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 64)
}

test "trace_flags_191" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 191)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 191)
}

test "trace_flags_192" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 192)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 192)
}

// === Comprehensive Multi-Scenario Tests ===

test "scenario_web_request_trace_1" {
  let trace_id = [87, 69, 66, 45, 82, 69, 81, 85, 69, 83, 84, 45, 49, 50, 51, 52]
  let span_id = [72, 65, 78, 68, 76, 69, 82, 49]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "scenario_database_query_trace" {
  let trace_id = [68, 66, 45, 81, 85, 69, 82, 89, 45, 84, 82, 65, 67, 69, 45, 49]
  let span_id = [83, 81, 76, 45, 83, 80, 65, 78]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "scenario_cache_operation_trace" {
  let trace_id = [67, 65, 67, 72, 69, 45, 79, 80, 45, 84, 82, 65, 67, 69, 45, 50]
  let span_id = [71, 69, 84, 45, 75, 69, 89, 49]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "scenario_api_call_trace" {
  let trace_id = [65, 80, 73, 45, 67, 65, 76, 76, 45, 84, 82, 65, 67, 69, 45, 51]
  let span_id = [72, 84, 84, 80, 45, 71, 69, 84]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "scenario_message_queue_trace" {
  let trace_id = [77, 81, 45, 77, 83, 71, 45, 84, 82, 65, 67, 69, 45, 52, 53, 54]
  let span_id = [80, 85, 66, 76, 73, 83, 72, 49]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}
