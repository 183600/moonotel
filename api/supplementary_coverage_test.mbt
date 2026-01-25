// Supplementary coverage tests for SpanContext and utility functions

// Test byte_to_hex_char with all values 0-15
test "byte_to_hex_char_all_values" {
  assert_eq!(byte_to_hex_char(0), "0")
  assert_eq!(byte_to_hex_char(1), "1")
  assert_eq!(byte_to_hex_char(2), "2")
  assert_eq!(byte_to_hex_char(3), "3")
  assert_eq!(byte_to_hex_char(4), "4")
  assert_eq!(byte_to_hex_char(5), "5")
  assert_eq!(byte_to_hex_char(6), "6")
  assert_eq!(byte_to_hex_char(7), "7")
  assert_eq!(byte_to_hex_char(8), "8")
  assert_eq!(byte_to_hex_char(9), "9")
  assert_eq!(byte_to_hex_char(10), "a")
  assert_eq!(byte_to_hex_char(11), "b")
  assert_eq!(byte_to_hex_char(12), "c")
  assert_eq!(byte_to_hex_char(13), "d")
  assert_eq!(byte_to_hex_char(14), "e")
  assert_eq!(byte_to_hex_char(15), "f")
}

// Test byte_to_hex_char with negative values
test "byte_to_hex_char_negative_values" {
  assert_eq!(byte_to_hex_char(-1), "0")
  assert_eq!(byte_to_hex_char(-5), "0")
  assert_eq!(byte_to_hex_char(-10), "0")
  assert_eq!(byte_to_hex_char(-15), "0")
}

// Test byte_to_hex_char with values > 15
test "byte_to_hex_char_out_of_range_positive" {
  assert_eq!(byte_to_hex_char(16), "0")
  assert_eq!(byte_to_hex_char(20), "0")
  assert_eq!(byte_to_hex_char(100), "0")
  assert_eq!(byte_to_hex_char(255), "0")
}

// Test bytes_to_hex with various combinations
test "bytes_to_hex_various_patterns_1" {
  let bytes = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77]
  assert_eq!(bytes_to_hex(bytes), "0011223344556677")
}

test "bytes_to_hex_various_patterns_2" {
  let bytes = [0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]
  assert_eq!(bytes_to_hex(bytes), "8899aabbccddeeff")
}

test "bytes_to_hex_interleaved_zeros" {
  let bytes = [0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff]
  assert_eq!(bytes_to_hex(bytes), "00ff00ff00ff00ff")
}

test "bytes_to_hex_all_same_byte" {
  let bytes = [0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa]
  assert_eq!(bytes_to_hex(bytes), "aaaaaaaaaaaaaaaa")
}

test "bytes_to_hex_alternating_pattern" {
  let bytes = [0x0f, 0xf0, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f, 0xf0]
  assert_eq!(bytes_to_hex(bytes), "0ff00ff00ff00ff0")
}

// Test is_zero with various array lengths and patterns
test "is_zero_single_element_zero" {
  let arr = [0]
  assert_true!(is_zero(arr))
}

test "is_zero_single_element_nonzero" {
  let arr = [1]
  assert_false!(is_zero(arr))
}

test "is_zero_two_elements_both_zero" {
  let arr = [0, 0]
  assert_true!(is_zero(arr))
}

test "is_zero_two_elements_first_nonzero" {
  let arr = [1, 0]
  assert_false!(is_zero(arr))
}

test "is_zero_two_elements_second_nonzero" {
  let arr = [0, 1]
  assert_false!(is_zero(arr))
}

test "is_zero_three_elements_all_zero" {
  let arr = [0, 0, 0]
  assert_true!(is_zero(arr))
}

test "is_zero_three_elements_middle_nonzero" {
  let arr = [0, 5, 0]
  assert_false!(is_zero(arr))
}

test "is_zero_seven_elements_last_nonzero" {
  let arr = [0, 0, 0, 0, 0, 0, 1]
  assert_false!(is_zero(arr))
}

test "is_zero_sixteen_elements_all_zero" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_true!(is_zero(arr))
}

test "is_zero_sixteen_elements_mixed" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255]
  assert_false!(is_zero(arr))
}

// Test span_context validation with various trace_id patterns
test "span_context_trace_id_all_zeros_length_16" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_false!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_trace_id_single_nonzero_at_start" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_id_single_nonzero_at_end" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_id_single_nonzero_in_middle" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_id_alternating_zeros_and_nonzeros" {
  let trace_id = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_id_all_255" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

// Test span_context validation with various span_id patterns
test "span_context_span_id_all_zeros_length_8" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_span_id_single_nonzero_at_start" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [255, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_span_id_single_nonzero_at_end" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 255]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_span_id_single_nonzero_in_middle" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 100, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_span_id_alternating_zeros_and_nonzeros" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 170, 0, 170, 0, 170, 0, 170]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_span_id_all_170" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [170, 170, 170, 170, 170, 170, 170, 170]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

// Test trace_flags variations
test "span_context_trace_flags_0" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 0)
  assert_true!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_trace_flags_1" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_2" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 2)
  assert_true!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_trace_flags_3" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 3)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_4" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 4)
  assert_true!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_trace_flags_5" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 5)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_6" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 6)
  assert_true!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_trace_flags_7" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 7)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_8" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 8)
  assert_true!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_trace_flags_9" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 9)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_10" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 10)
  assert_true!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_trace_flags_11" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 11)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_12" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 12)
  assert_true!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_trace_flags_13" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 13)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_14" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 14)
  assert_true!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_trace_flags_15" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 15)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_16" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 16)
  assert_true!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_trace_flags_17" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 17)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_18" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 18)
  assert_true!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

test "span_context_trace_flags_19" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 19)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_negatives" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, -1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_negative_odd" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, -3)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

test "span_context_trace_flags_negative_even" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, -2)
  assert_true!(sc.is_valid())
  assert_false!(sc.is_sampled())
}

// Test edge cases for span_context with wrong array lengths
test "span_context_trace_id_wrong_length_15" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_false!(sc.is_valid())
}

test "span_context_trace_id_wrong_length_17" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_false!(sc.is_valid())
}

test "span_context_span_id_wrong_length_7" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7]
  let sc = span_context(trace_id, span_id, 1)
  assert_false!(sc.is_valid())
}

test "span_context_span_id_wrong_length_9" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8, 9]
  let sc = span_context(trace_id, span_id, 1)
  assert_false!(sc.is_valid())
}

test "span_context_both_ids_wrong_length" {
  let trace_id = [1, 2, 3, 4, 5]
  let span_id = [1, 2, 3]
  let sc = span_context(trace_id, span_id, 1)
  assert_false!(sc.is_valid())
}

test "span_context_both_ids_correct_length_all_valid_bytes" {
  let trace_id = [255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0]
  let span_id = [170, 85, 170, 85, 170, 85, 170, 85]
  let sc = span_context(trace_id, span_id, 1)
  assert_true!(sc.is_valid())
  assert_true!(sc.is_sampled())
}

// Test hex encoding consistency
test "span_context_hex_encoding_consistency" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq!(sc.trace_id_hex(), "0102030405060708090a0b0c0d0e0f10")
  assert_eq!(sc.span_id_hex(), "1112131415161718")
  assert_eq!(sc.trace_id_hex(), sc.trace_id_hex())
  assert_eq!(sc.span_id_hex(), sc.span_id_hex())
}

test "invalid_span_context_hex_encoding" {
  let sc = invalid_span_context()
  assert_eq!(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq!(sc.span_id_hex(), "0000000000000000")
  assert_eq!(sc.trace_flags, 0)
  assert_false!(sc.is_valid())
}

// Test multiple calls to is_sampled consistency
test "span_context_is_sampled_consistency" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq!(sc.is_sampled(), sc.is_sampled())
  assert_eq!(sc.is_sampled(), true)
}

test "span_context_is_sampled_false_consistency" {
  let sc = invalid_span_context()
  assert_eq!(sc.is_sampled(), sc.is_sampled())
  assert_eq!(sc.is_sampled(), false)
}
