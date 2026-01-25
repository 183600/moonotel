// New comprehensive functional tests for SpanContext and related functionality

test "span_context_with_max_trace_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [21, 22, 23, 24, 25, 26, 27, 28]
  let flags = 255
  
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "span_context_with_odd_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [21, 22, 23, 24, 25, 26, 27, 28]
  let flags = 3
  
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "span_context_with_even_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [21, 22, 23, 24, 25, 26, 27, 28]
  let flags = 2
  
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "hex_encoding_all_zeros" {
  let zeros = Array::make(16, 0)
  let result = bytes_to_hex(zeros)
  assert_eq(result, "00000000000000000000000000000000")
}

test "hex_encoding_all_255" {
  let maxes = Array::make(16, 255)
  let result = bytes_to_hex(maxes)
  assert_eq(result, "ffffffffffffffffffffffffffffffff")
}

test "hex_encoding_alternating" {
  let data = [15, 240, 15, 240, 15, 240, 15, 240]
  let result = bytes_to_hex(data)
  assert_eq(result, "0ff00ff00ff00ff0")
}

test "is_zero_with_single_nonzero" {
  let arr = [0, 0, 0, 0, 1, 0, 0, 0]
  assert_false(is_zero(arr))
}

test "is_zero_with_all_zeros" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 0]
  assert_true(is_zero(arr))
}

test "is_zero_with_last_nonzero" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 1]
  assert_false(is_zero(arr))
}

test "is_zero_with_first_nonzero" {
  let arr = [1, 0, 0, 0, 0, 0, 0, 0]
  assert_false(is_zero(arr))
}

test "byte_to_hex_char_boundary_values" {
  assert_eq(byte_to_hex_char(0), "0")
  assert_eq(byte_to_hex_char(15), "f")
  assert_eq(byte_to_hex_char(10), "a")
  assert_eq(byte_to_hex_char(5), "5")
}

test "span_context_trace_id_length_validation" {
  let short_trace = [1, 2, 3, 4, 5, 6, 7, 8]
  let span_id = [10, 11, 12, 13, 14, 15, 16, 17]
  let sc = span_context(short_trace, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_span_id_length_validation" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let short_span = [10, 11, 12, 13]
  let sc = span_context(trace_id, short_span, 1)
  assert_false(sc.is_valid())
}

test "span_context_with_high_byte_values" {
  let trace_id = [255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240]
  let span_id = [239, 238, 237, 236, 235, 234, 233, 232]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "hex_conversion_symmetry" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let hex1 = bytes_to_hex(trace_id)
  let hex2 = bytes_to_hex(trace_id)
  assert_eq(hex1, hex2)
}

test "multiple_span_contexts_independence" {
  let trace1 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span1 = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc1 = span_context(trace1, span1, 1)
  
  let trace2 = [25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40]
  let span2 = [41, 42, 43, 44, 45, 46, 47, 48]
  let sc2 = span_context(trace2, span2, 0)
  
  assert_true(sc1.is_valid())
  assert_true(sc2.is_valid())
  assert_true(sc1.is_sampled())
  assert_false(sc2.is_sampled())
}

test "invalid_context_hex_operations" {
  let sc = invalid_span_context()
  let trace_hex = sc.trace_id_hex()
  let span_hex = sc.span_id_hex()
  
  assert_eq(trace_hex.length(), 32)
  assert_eq(span_hex.length(), 16)
}

test "span_context_flags_bit_operations" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  
  let sc_flags_4 = span_context(trace_id, span_id, 4)
  assert_false(sc_flags_4.is_sampled())
  
  let sc_flags_5 = span_context(trace_id, span_id, 5)
  assert_true(sc_flags_5.is_sampled())
}

test "bytes_to_hex_empty_array" {
  let empty = Array::make(0, 0)
  let result = bytes_to_hex(empty)
  assert_eq(result, "")
}

test "bytes_to_hex_single_byte" {
  let single = [170]
  let result = bytes_to_hex(single)
  assert_eq(result, "aa")
}

test "span_context_mixed_byte_values" {
  let trace_id = [0, 15, 16, 31, 32, 47, 48, 63, 64, 79, 80, 95, 96, 111, 112, 127]
  let span_id = [128, 143, 144, 159, 160, 175, 176, 191]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "is_zero_single_element" {
  let arr_zero = [0]
  let arr_one = [1]
  assert_true(is_zero(arr_zero))
  assert_false(is_zero(arr_one))
}

test "span_context_maximum_valid_ids" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc = span_context(trace_id, span_id, 255)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "span_context_minimum_valid_ids" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "hex_encoding_pattern_test_1" {
  let data = [17, 34, 51, 68]
  let result = bytes_to_hex(data)
  assert_eq(result, "11223344")
}

test "hex_encoding_pattern_test_2" {
  let data = [85, 102, 119, 136]
  let result = bytes_to_hex(data)
  assert_eq(result, "55667788")
}

test "hex_encoding_pattern_test_3" {
  let data = [153, 170, 187, 204]
  let result = bytes_to_hex(data)
  assert_eq(result, "99aabbcc")
}

test "span_context_flags_negative_value" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, -1)
  assert_true(sc.is_valid())
}

test "is_zero_large_array" {
  let large_zeros = Array::make(100, 0)
  assert_true(is_zero(large_zeros))
}

test "is_zero_large_array_with_one_nonzero" {
  let large_array = Array::make(100, 0)
  large_array[50] = 1
  assert_false(is_zero(large_array))
}

test "span_id_hex_all_same_value" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [170, 170, 170, 170, 170, 170, 170, 170]
  let sc = span_context(trace_id, span_id, 1)
  let hex = sc.span_id_hex()
  assert_eq(hex, "aaaaaaaaaaaaaaaa")
}

test "trace_id_hex_sequential_values" {
  let trace_id = [16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 192, 208, 224, 240, 255]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  let hex = sc.trace_id_hex()
  assert_eq(hex.length(), 32)
}

test "span_context_creation_stability" {
  let trace_id = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]
  let span_id = [200, 201, 202, 203, 204, 205, 206, 207]
  
  let sc1 = span_context(trace_id, span_id, 1)
  let sc2 = span_context(trace_id, span_id, 1)
  
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
  assert_eq(sc1.span_id_hex(), sc2.span_id_hex())
  assert_eq(sc1.is_sampled(), sc2.is_sampled())
}

test "byte_to_hex_all_values" {
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

test "span_context_alternating_bits" {
  let trace_id = [85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170]
  let span_id = [170, 85, 170, 85, 170, 85, 170, 85]
  let sc = span_context(trace_id, span_id, 85)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "invalid_trace_id_all_zeros" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "invalid_span_id_all_zeros" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "hex_encoding_nibble_boundaries" {
  let data = [0, 1, 14, 15, 16, 17, 238, 239, 240, 241, 254, 255]
  let result = bytes_to_hex(data)
  assert_eq(result, "00010e0f1011eeeff0f1feff")
}

test "span_context_power_of_two_values" {
  let trace_id = [1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128]
  let span_id = [1, 2, 4, 8, 16, 32, 64, 128]
  let sc = span_context(trace_id, span_id, 8)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "span_context_prime_number_values" {
  let trace_id = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53]
  let span_id = [59, 61, 67, 71, 73, 79, 83, 89]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "bytes_to_hex_consistency" {
  let data1 = [1, 2, 3, 4, 5]
  let data2 = [1, 2, 3, 4, 5]
  assert_eq(bytes_to_hex(data1), bytes_to_hex(data2))
}

test "span_context_trace_flags_overflow" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 256)
  assert_true(sc.is_valid())
}

test "hex_values_lowercase_verification" {
  let data = [171, 205, 239, 255]
  let result = bytes_to_hex(data)
  assert_eq(result, "abcdefff")
}

test "is_zero_empty_array" {
  let empty = Array::make(0, 0)
  assert_true(is_zero(empty))
}

test "span_context_sequential_trace_ids" {
  let trace1 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  let trace2 = [2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]
  let span_id = [10, 11, 12, 13, 14, 15, 16, 17]
  
  let sc1 = span_context(trace1, span_id, 1)
  let sc2 = span_context(trace2, span_id, 1)
  
  assert_true(sc1.is_valid())
  assert_true(sc2.is_valid())
  assert_true(sc1.trace_id_hex() != sc2.trace_id_hex())
}

test "span_context_sequential_span_ids" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span1 = [1, 1, 1, 1, 1, 1, 1, 1]
  let span2 = [2, 2, 2, 2, 2, 2, 2, 2]
  
  let sc1 = span_context(trace_id, span1, 1)
  let sc2 = span_context(trace_id, span2, 1)
  
  assert_true(sc1.is_valid())
  assert_true(sc2.is_valid())
  assert_true(sc1.span_id_hex() != sc2.span_id_hex())
}

test "span_context_same_trace_different_spans" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span1 = [11, 22, 33, 44, 55, 66, 77, 88]
  let span2 = [99, 88, 77, 66, 55, 44, 33, 22]
  
  let sc1 = span_context(trace_id, span1, 1)
  let sc2 = span_context(trace_id, span2, 1)
  
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
  assert_true(sc1.span_id_hex() != sc2.span_id_hex())
}

test "hex_encoding_full_spectrum" {
  let data = [0, 16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 192, 208, 224, 240]
  let result = bytes_to_hex(data)
  assert_eq(result.length(), 32)
}

test "span_context_flags_with_multiple_bits_set" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  
  let sc7 = span_context(trace_id, span_id, 7)
  let sc15 = span_context(trace_id, span_id, 15)
  let sc31 = span_context(trace_id, span_id, 31)
  
  assert_true(sc7.is_sampled())
  assert_true(sc15.is_sampled())
  assert_true(sc31.is_sampled())
}

test "span_context_boundary_byte_values" {
  let trace_id = [0, 1, 126, 127, 128, 129, 254, 255, 0, 1, 126, 127, 128, 129, 254, 255]
  let span_id = [0, 1, 126, 127, 128, 129, 254, 255]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "invalid_context_maintains_structure" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_id.length(), 16)
  assert_eq(sc.span_id.length(), 8)
  assert_eq(sc.trace_flags, 0)
  assert_false(sc.is_valid())
}

test "span_context_with_repeating_patterns" {
  let trace_id = [12, 34, 12, 34, 12, 34, 12, 34, 12, 34, 12, 34, 12, 34, 12, 34]
  let span_id = [56, 78, 56, 78, 56, 78, 56, 78]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "bytes_to_hex_long_array" {
  let long_data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
  let result = bytes_to_hex(long_data)
  assert_eq(result.length(), 40)
}

test "span_context_validity_check_consistency" {
  let trace_id = [50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65]
  let span_id = [70, 71, 72, 73, 74, 75, 76, 77]
  let sc = span_context(trace_id, span_id, 1)
  
  assert_true(sc.is_valid())
  assert_true(sc.is_valid())
  assert_true(sc.is_valid())
}

test "hex_encoding_special_sequences" {
  let data1 = [0, 255, 0, 255]
  let data2 = [255, 0, 255, 0]
  
  assert_eq(bytes_to_hex(data1), "00ff00ff")
  assert_eq(bytes_to_hex(data2), "ff00ff00")
}
