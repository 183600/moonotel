// Tests for utility functions in span_context.mbt

test "is_zero_all_zero_single_byte" {
  assert_true(is_zero([0]))
}

test "is_zero_non_zero_single_byte" {
  assert_false(is_zero([1]))
}

test "is_zero_mixed_zeros" {
  assert_false(is_zero([0, 1, 0, 0]))
}

test "is_zero_mixed_zeros_end" {
  assert_false(is_zero([0, 0, 1, 0]))
}

test "is_zero_mixed_zeros_middle" {
  assert_false(is_zero([0, 1, 0, 0]))
}

test "is_zero_single_byte_array" {
  assert_true(is_zero([0]))
}

test "is_zero_two_bytes_all_zero" {
  assert_true(is_zero([0, 0]))
}

test "is_zero_two_bytes_first_non_zero" {
  assert_false(is_zero([1, 0]))
}

test "is_zero_two_bytes_second_non_zero" {
  assert_false(is_zero([0, 1]))
}

test "is_zero_two_bytes_both_non_zero" {
  assert_false(is_zero([1, 2]))
}

test "is_zero_three_bytes_all_zero" {
  assert_true(is_zero([0, 0, 0]))
}

test "is_zero_three_bytes_one_non_zero" {
  assert_false(is_zero([0, 1, 0]))
}

test "is_zero_three_bytes_two_non_zero" {
  assert_false(is_zero([1, 0, 2]))
}

test "is_zero_four_bytes_all_zero" {
  assert_true(is_zero([0, 0, 0, 0]))
}

test "is_zero_five_bytes_all_zero" {
  assert_true(is_zero([0, 0, 0, 0, 0]))
}

test "is_zero_six_bytes_all_zero" {
  assert_true(is_zero([0, 0, 0, 0, 0, 0]))
}

test "is_zero_seven_bytes_all_zero" {
  assert_true(is_zero([0, 0, 0, 0, 0, 0, 0]))
}

test "is_zero_nine_bytes_all_zero" {
  assert_true(is_zero([0, 0, 0, 0, 0, 0, 0, 0, 0]))
}

test "is_zero_fifteen_bytes_all_zero" {
  assert_true(is_zero([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
}

test "is_zero_seventeen_bytes_all_zero" {
  assert_true(is_zero([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
}

test "is_zero_last_byte_non_zero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  assert_false(is_zero(trace_id))
}

test "is_zero_first_byte_non_zero" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_false(is_zero(trace_id))
}

test "is_zero_middle_byte_non_zero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0]
  assert_false(is_zero(trace_id))
}

test "byte_to_hex_char_zero_to_fifteen" {
  assert_eq(byte_to_hex_char(0), "0")
  assert_eq(byte_to_hex_char(1), "1")
  assert_eq(byte_to_hex_char(2), "2")
  assert_eq(byte_to_hex_char(3), "3")
  assert_eq(byte_to_hex_char(4), "4")
  assert_eq(byte_to_hex_char(5), "5")
  assert_eq(byte_to_hex_char(6), "6")
  assert_eq(byte_to_hex_char(7), "7")
  assert_eq(byte_to_hex_char(8), "8")
  assert_eq(byte_to_hex_char(9), "9")
  assert_eq(byte_to_hex_char(10), "a")
  assert_eq(byte_to_hex_char(11), "b")
  assert_eq(byte_to_hex_char(12), "c")
  assert_eq(byte_to_hex_char(13), "d")
  assert_eq(byte_to_hex_char(14), "e")
  assert_eq(byte_to_hex_char(15), "f")
}

test "byte_to_hex_char_boundary_negative_one" {
  assert_eq(byte_to_hex_char(-1), "0")
}

test "byte_to_hex_char_boundary_sixteen" {
  assert_eq(byte_to_hex_char(16), "0")
}

test "byte_to_hex_char_large_value" {
  assert_eq(byte_to_hex_char(100), "0")
}

test "byte_to_hex_char_very_large_value" {
  assert_eq(byte_to_hex_char(255), "0")
}

test "bytes_to_hex_single_byte_each_value" {
  let mut i = 0
  while i < 16 {
    let hex = bytes_to_hex([i])
    assert_true(hex.length() == 2)
    i = i + 1
  }
}

test "bytes_to_hex_two_bytes_pattern" {
  let arr = [0x12, 0x34]
  assert_eq(bytes_to_hex(arr), "1234")
}

test "bytes_to_hex_two_bytes_reverse" {
  let arr = [0x34, 0x12]
  assert_eq(bytes_to_hex(arr), "3412")
}

test "bytes_to_hex_three_bytes_pattern" {
  let arr = [0x12, 0x34, 0x56]
  assert_eq(bytes_to_hex(arr), "123456")
}

test "bytes_to_hex_five_bytes_pattern" {
  let arr = [0x11, 0x22, 0x33, 0x44, 0x55]
  assert_eq(bytes_to_hex(arr), "1122334455")
}

test "bytes_to_hex_six_bytes_pattern" {
  let arr = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06]
  assert_eq(bytes_to_hex(arr), "010203040506")
}

test "bytes_to_hex_seven_bytes_pattern" {
  let arr = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD]
  assert_eq(bytes_to_hex(arr), "0123456789abcd")
}

test "bytes_to_hex_nine_bytes_pattern" {
  let arr = [1, 2, 3, 4, 5, 6, 7, 8, 9]
  assert_eq(bytes_to_hex(arr), "010203040506070809")
}

test "bytes_to_hex_fifteen_bytes_pattern" {
  let arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(arr)
  assert_true(hex.length() == 30)
}

test "bytes_to_hex_seventeen_bytes_pattern" {
  let arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  let hex = bytes_to_hex(arr)
  assert_true(hex.length() == 34)
}

test "bytes_to_hex_all_max_bytes" {
  let arr = [0xFF, 0xFF, 0xFF, 0xFF]
  assert_eq(bytes_to_hex(arr), "ffffffff")
}

test "bytes_to_hex_all_min_bytes" {
  let arr = [0x00, 0x00, 0x00, 0x00]
  assert_eq(bytes_to_hex(arr), "00000000")
}

test "bytes_to_hex_alternating_max_min" {
  let arr = [0xFF, 0x00, 0xFF, 0x00]
  assert_eq(bytes_to_hex(arr), "ff00ff00")
}

test "bytes_to_hex_binary_pattern_10101010" {
  let arr = [0b10101010]
  assert_eq(bytes_to_hex(arr), "aa")
}

test "bytes_to_hex_binary_pattern_01010101" {
  let arr = [0b01010101]
  assert_eq(bytes_to_hex(arr), "55")
}

test "bytes_to_hex_boundary_low_high_nibble" {
  assert_eq(bytes_to_hex([0x0F]), "0f")
  assert_eq(bytes_to_hex([0xF0]), "f0")
}

test "bytes_to_hex_repeated_byte_values" {
  let arr = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]
  assert_eq(bytes_to_hex(arr), "1122334455667788")
}

test "bytes_to_hex_increasing_byte_sequence" {
  let arr = [1, 2, 3, 4, 5, 6, 7, 8]
  assert_eq(bytes_to_hex(arr), "0102030405060708")
}

test "bytes_to_hex_decreasing_byte_sequence" {
  let arr = [8, 7, 6, 5, 4, 3, 2, 1]
  assert_eq(bytes_to_hex(arr), "0807060504030201")
}

test "bytes_to_hex_single_byte_zero" {
  assert_eq(bytes_to_hex([0]), "00")
}

test "bytes_to_hex_single_byte_max" {
  assert_eq(bytes_to_hex([255]), "ff")
}

test "bytes_to_hex_single_byte_middle" {
  assert_eq(bytes_to_hex([128]), "80")
}

test "bytes_to_hex_check_character_set" {
  let hex = bytes_to_hex([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
  assert_eq(hex, "000102030405060708090a0b0c0d0e0f")
}

test "bytes_to_hex_zero_to_sixteen" {
  let arr = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  assert_eq(bytes_to_hex(arr), "000102030405060708090a0b0c0d0e0f10")
}

test "bytes_to_hex_case_sensitivity_lower" {
  assert_eq(bytes_to_hex([0xAB]), "ab")
  assert_eq(bytes_to_hex([0xCD]), "cd")
  assert_eq(bytes_to_hex([0xEF]), "ef")
}

test "bytes_to_hex_null_byte_handling" {
  let arr = [0x00, 0x01, 0x02, 0x00]
  assert_eq(bytes_to_hex(arr), "00010200")
}

test "span_context_trace_flags_255" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let flags = 255
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 255)
}

test "span_context_trace_flags_128" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let flags = 128
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "span_context_trace_flags_3" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let flags = 3
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "span_context_trace_flags_2" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let flags = 2
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "span_context_with_min_valid_ids" {
  let trace_id = Array::make(16, 0)
  let span_id = Array::make(8, 0)
  trace_id[0] = 1
  span_id[0] = 1
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_context_with_last_byte_non_zero_trace" {
  let trace_id = Array::make(16, 0)
  let span_id = Array::make(8, 0)
  trace_id[15] = 1
  span_id[0] = 1
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_context_with_last_byte_non_zero_span" {
  let trace_id = Array::make(16, 0)
  let span_id = Array::make(8, 0)
  trace_id[0] = 1
  span_id[7] = 1
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_context_invalid_both_zero" {
  let trace_id = Array::make(16, 0)
  let span_id = Array::make(8, 0)
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_context_invalid_trace_zero_span_ok" {
  let trace_id = Array::make(16, 0)
  let span_id = Array::make(8, 0)
  span_id[0] = 1
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_context_invalid_span_zero_trace_ok" {
  let trace_id = Array::make(16, 0)
  let span_id = Array::make(8, 0)
  trace_id[0] = 1
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_context_length_check_short_trace" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_context_length_check_long_trace" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_context_length_check_short_span" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_context_length_check_long_span" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8, 9]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_context_both_length_invalid" {
  let trace_id = [1, 2, 3, 4, 5]
  let span_id = [1, 2, 3]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "invalid_span_context_default_fields" {
  let sc = invalid_span_context()
  assert_false(sc.is_valid())
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 0)
}

test "span_context_hex_output_lowercase" {
  let trace_id = [0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89]
  let span_id = [0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89]
  let sc = span_context(trace_id, span_id, 0)
  let trace_hex = sc.trace_id_hex()
  let span_hex = sc.span_id_hex()
  assert_eq(trace_hex, "abcdef0123456789abcdef0123456789")
  assert_eq(span_hex, "abcdef0123456789")
}

test "span_context_mixed_case_bytes" {
  let trace_id = [0xAB, 0xCD, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC]
  let span_id = [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "is_zero_function_edge_cases" {
  assert_true(is_zero([]))
  assert_false(is_zero([1]))
}

test "bytes_to_hex_empty_array" {
  assert_eq(bytes_to_hex([]), "")
}

test "trace_id_hex_for_valid_context" {
  let trace_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]
  let span_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
  let sc = span_context(trace_id, span_id, 0)
  assert_eq(sc.trace_id_hex(), "0102030405060708090a0b0c0d0e0f10")
}

test "span_id_hex_for_valid_context" {
  let trace_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]
  let span_id = [0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xFA, 0xF9, 0xF8]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.span_id_hex(), "fffefdfcfbfaf9f8")
}

test "is_sampled_all_trace_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let mut i = 0
  while i < 10 {
    let sc = span_context(trace_id, span_id, i)
    if (i & 1) == 0 {
      assert_false(sc.is_sampled())
    } else {
      assert_true(sc.is_sampled())
    }
    i = i + 1
  }
}

test "byte_to_hex_char_consistency" {
  let arr = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(arr)
  assert_eq(hex, "000102030405060708090a0b0c0d0e0f")
}

test "bytes_to_hex_consistency_check" {
  let arr1 = [1, 2, 3]
  let arr2 = [1, 2, 3]
  assert_eq(bytes_to_hex(arr1), bytes_to_hex(arr2))
}

test "span_context_immutability_check" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  let hex1 = sc.trace_id_hex()
  let hex2 = sc.trace_id_hex()
  assert_eq(hex1, hex2)
}

test "invalid_span_context_hex_output" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
}

test "span_context_with_special_byte_patterns" {
  let trace_id = [0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55]
  let span_id = [0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "aa55aa55aa55aa55aa55aa55aa55aa55")
  assert_eq(sc.span_id_hex(), "aa55aa55aa55aa55")
}
