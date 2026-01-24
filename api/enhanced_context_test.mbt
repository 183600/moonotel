// Enhanced comprehensive tests for SpanContext functionality

// Tests for byte_to_hex_char with all valid inputs
test "byte_to_hex_char_0" {
  assert_eq(byte_to_hex_char(0), "0")
}

test "byte_to_hex_char_1" {
  assert_eq(byte_to_hex_char(1), "1")
}

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

test "byte_to_hex_char_9" {
  assert_eq(byte_to_hex_char(9), "9")
}

test "byte_to_hex_char_10" {
  assert_eq(byte_to_hex_char(10), "a")
}

test "byte_to_hex_char_11" {
  assert_eq(byte_to_hex_char(11), "b")
}

test "byte_to_hex_char_12" {
  assert_eq(byte_to_hex_char(12), "c")
}

test "byte_to_hex_char_13" {
  assert_eq(byte_to_hex_char(13), "d")
}

test "byte_to_hex_char_14" {
  assert_eq(byte_to_hex_char(14), "e")
}

test "byte_to_hex_char_15" {
  assert_eq(byte_to_hex_char(15), "f")
}

// Tests for various trace flag combinations
test "trace_flags_all_zeros" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 0)
}

test "trace_flags_bit_0_only" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 1)
}

test "trace_flags_bit_1_only" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 2)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 2)
}

test "trace_flags_bit_0_and_1" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 3)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 3)
}

test "trace_flags_128" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 128)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 128)
}

test "trace_flags_129" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 129)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 129)
}

test "trace_flags_254" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 254)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 254)
}

test "trace_flags_255" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 255)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 255)
}

// Pattern-based tests for trace IDs
test "trace_id_ascending_sequence" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "000102030405060708090a0b0c0d0e0f")
}

test "trace_id_descending_sequence" {
  let trace_id = [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  let span_id = [8, 7, 6, 5, 4, 3, 2, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "0f0e0d0c0b0a09080706050403020100")
}

test "trace_id_all_ones" {
  let trace_id = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  let span_id = [1, 1, 1, 1, 1, 1, 1, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex().length(), 32)
}

test "trace_id_alternating_0_255" {
  let trace_id = [0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255]
  let span_id = [255, 0, 255, 0, 255, 0, 255, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "trace_id_powers_of_two" {
  let trace_id = [1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128]
  let span_id = [1, 2, 4, 8, 16, 32, 64, 128]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

// Span ID pattern tests
test "span_id_all_max_value" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

test "span_id_single_nonzero_first" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0100000000000000")
}

test "span_id_single_nonzero_last" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0000000000000001")
}

test "span_id_middle_nonzero" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 42, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0000002a00000000")
}

// is_zero helper comprehensive tests
test "is_zero_empty_array" {
  let arr : Array[Int] = []
  assert_true(is_zero(arr))
}

test "is_zero_single_zero" {
  assert_true(is_zero([0]))
}

test "is_zero_single_nonzero" {
  assert_false(is_zero([1]))
}

test "is_zero_multiple_zeros" {
  assert_true(is_zero([0, 0, 0, 0, 0]))
}

test "is_zero_first_nonzero" {
  assert_false(is_zero([1, 0, 0, 0]))
}

test "is_zero_middle_nonzero" {
  assert_false(is_zero([0, 0, 1, 0, 0]))
}

test "is_zero_last_nonzero" {
  assert_false(is_zero([0, 0, 0, 0, 1]))
}

test "is_zero_all_nonzero" {
  assert_false(is_zero([1, 2, 3, 4]))
}

test "is_zero_large_array" {
  let zeros = Array::make(100, 0)
  assert_true(is_zero(zeros))
}

test "is_zero_large_array_one_nonzero" {
  let arr = Array::make(100, 0)
  arr[50] = 1
  assert_false(is_zero(arr))
}

// Validity edge cases
test "span_context_wrong_trace_id_length_15" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_wrong_trace_id_length_17" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_wrong_span_id_length_7" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_wrong_span_id_length_9" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8, 9]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_both_lengths_wrong" {
  let trace_id = [1, 2, 3]
  let span_id = [1, 2]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

// Hex encoding with special byte patterns
test "bytes_to_hex_nibble_boundaries" {
  assert_eq(bytes_to_hex([0x0F, 0xF0]), "0ff0")
}

test "bytes_to_hex_consecutive_values" {
  assert_eq(bytes_to_hex([0, 1, 2, 3, 4, 5]), "000102030405")
}

test "bytes_to_hex_high_nibble_zero" {
  assert_eq(bytes_to_hex([0x01, 0x02, 0x03, 0x04]), "01020304")
}

test "bytes_to_hex_low_nibble_zero" {
  assert_eq(bytes_to_hex([0x10, 0x20, 0x30, 0x40]), "10203040")
}

test "bytes_to_hex_mixed_nibbles" {
  assert_eq(bytes_to_hex([0x12, 0x34, 0x56, 0x78]), "12345678")
}

test "bytes_to_hex_upper_half_bytes" {
  assert_eq(bytes_to_hex([128, 129, 254, 255]), "8081feff")
}

// Invalid SpanContext comprehensive checks
test "invalid_span_context_fields_immutable" {
  let sc1 = invalid_span_context()
  let sc2 = invalid_span_context()
  assert_false(sc1.is_valid())
  assert_false(sc2.is_valid())
}

test "invalid_span_context_trace_flags" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_flags, 0)
  assert_false(sc.is_sampled())
}

// Complex hex patterns
test "trace_id_hex_magic_numbers" {
  let trace_id = [0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE, 0xFE, 0xED, 0xFA, 0xCE, 0x12, 0x34, 0x56, 0x78]
  let span_id = [0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "deadbeefcafebabefeedface12345678")
  assert_eq(sc.span_id_hex(), "abcdef0123456789")
}

// Combined validation and sampling tests
test "valid_sampled_context" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [11, 22, 33, 44, 55, 66, 77, 88]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "valid_not_sampled_context" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [11, 22, 33, 44, 55, 66, 77, 88]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "valid_sampled_with_extra_flags" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [11, 22, 33, 44, 55, 66, 77, 88]
  let sc = span_context(trace_id, span_id, 0xFF)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

// Boundary tests for hex encoding
test "bytes_to_hex_single_byte" {
  assert_eq(bytes_to_hex([0xA5]), "a5")
}

test "bytes_to_hex_two_bytes" {
  assert_eq(bytes_to_hex([0xA5, 0x5A]), "a55a")
}

test "bytes_to_hex_odd_values" {
  assert_eq(bytes_to_hex([1, 3, 5, 7, 9]), "0103050709")
}

test "bytes_to_hex_even_values" {
  assert_eq(bytes_to_hex([0, 2, 4, 6, 8]), "0002040608")
}

test "bytes_to_hex_fibonacci_sequence" {
  assert_eq(bytes_to_hex([1, 1, 2, 3, 5, 8, 13]), "0101020305080d")
}
