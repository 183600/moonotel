// Advanced boundary and edge case tests

test "span_context_oversized_trace_id" {
  let oversized_trace = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
  let span_id = [21, 22, 23, 24, 25, 26, 27, 28]
  let sc = span_context(oversized_trace, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_oversized_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let oversized_span = [21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]
  let sc = span_context(trace_id, oversized_span, 1)
  assert_false(sc.is_valid())
}

test "span_context_undersized_trace_id" {
  let undersized_trace = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [21, 22, 23, 24, 25, 26, 27, 28]
  let sc = span_context(undersized_trace, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_undersized_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let undersized_span = [21, 22, 23, 24, 25, 26, 27]
  let sc = span_context(trace_id, undersized_span, 1)
  assert_false(sc.is_valid())
}

test "span_context_empty_trace_id" {
  let empty_trace = Array::make(0, 0)
  let span_id = [21, 22, 23, 24, 25, 26, 27, 28]
  let sc = span_context(empty_trace, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_empty_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let empty_span = Array::make(0, 0)
  let sc = span_context(trace_id, empty_span, 1)
  assert_false(sc.is_valid())
}

test "hex_encoding_boundary_128" {
  let data = [127, 128, 129]
  let result = bytes_to_hex(data)
  assert_eq(result, "7f8081")
}

test "hex_encoding_powers_of_16" {
  let data = [16, 32, 48, 64, 80, 96, 112, 128]
  let result = bytes_to_hex(data)
  assert_eq(result, "1020304050607080")
}

test "is_zero_negative_values" {
  let arr = [-1, 0, 0, 0]
  assert_false(is_zero(arr))
}

test "span_context_mixed_validity" {
  let valid_trace = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let valid_span = [17, 18, 19, 20, 21, 22, 23, 24]
  let zero_trace = Array::make(16, 0)
  let zero_span = Array::make(8, 0)
  
  let sc1 = span_context(valid_trace, valid_span, 1)
  let sc2 = span_context(zero_trace, valid_span, 1)
  let sc3 = span_context(valid_trace, zero_span, 1)
  let sc4 = span_context(zero_trace, zero_span, 1)
  
  assert_true(sc1.is_valid())
  assert_false(sc2.is_valid())
  assert_false(sc3.is_valid())
  assert_false(sc4.is_valid())
}

test "span_context_sampled_flag_isolation" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  
  let sc0 = span_context(trace_id, span_id, 0)
  let sc1 = span_context(trace_id, span_id, 1)
  let sc2 = span_context(trace_id, span_id, 2)
  let sc3 = span_context(trace_id, span_id, 3)
  
  assert_false(sc0.is_sampled())
  assert_true(sc1.is_sampled())
  assert_false(sc2.is_sampled())
  assert_true(sc3.is_sampled())
}

test "bytes_to_hex_incremental_values" {
  let data = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let result = bytes_to_hex(data)
  assert_eq(result, "000102030405060708090a0b0c0d0e0f")
}

test "bytes_to_hex_decremental_values" {
  let data = [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  let result = bytes_to_hex(data)
  assert_eq(result, "0f0e0d0c0b0a09080706050403020100")
}

test "span_context_single_bit_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_single_bit_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 128]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "hex_char_out_of_range" {
  let result = byte_to_hex_char(16)
  assert_eq(result, "0")
}

test "hex_char_large_value" {
  let result = byte_to_hex_char(255)
  assert_eq(result, "0")
}

test "is_zero_all_negative" {
  let arr = [-1, -2, -3, -4]
  assert_false(is_zero(arr))
}

test "span_context_trace_id_with_pattern" {
  let trace_id = [240, 15, 240, 15, 240, 15, 240, 15, 240, 15, 240, 15, 240, 15, 240, 15]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  let hex = sc.trace_id_hex()
  assert_eq(hex, "f00ff00ff00ff00ff00ff00ff00ff00f")
}

test "span_context_span_id_with_pattern" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [240, 15, 240, 15, 240, 15, 240, 15]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  let hex = sc.span_id_hex()
  assert_eq(hex, "f00ff00ff00ff00f")
}

test "multiple_invalid_contexts_independence" {
  let inv1 = invalid_span_context()
  let inv2 = invalid_span_context()
  
  assert_false(inv1.is_valid())
  assert_false(inv2.is_valid())
  assert_eq(inv1.trace_id_hex(), inv2.trace_id_hex())
  assert_eq(inv1.span_id_hex(), inv2.span_id_hex())
}

test "span_context_flags_large_positive" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 1000000)
  assert_true(sc.is_valid())
}

test "span_context_flags_large_negative" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, -1000000)
  assert_true(sc.is_valid())
}

test "hex_encoding_ascii_range" {
  let data = [65, 66, 67, 68, 69, 70, 71, 72]
  let result = bytes_to_hex(data)
  assert_eq(result, "4142434445464748")
}

test "span_context_interleaved_values" {
  let trace_id = [1, 255, 1, 255, 1, 255, 1, 255, 1, 255, 1, 255, 1, 255, 1, 255]
  let span_id = [255, 1, 255, 1, 255, 1, 255, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "is_zero_medium_size_array" {
  let arr = Array::make(50, 0)
  assert_true(is_zero(arr))
}

test "is_zero_medium_size_array_with_nonzero" {
  let arr = Array::make(50, 0)
  arr[25] = 100
  assert_false(is_zero(arr))
}

test "bytes_to_hex_repeated_byte" {
  let data = [85, 85, 85, 85]
  let result = bytes_to_hex(data)
  assert_eq(result, "55555555")
}

test "span_context_validation_after_creation" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [11, 22, 33, 44, 55, 66, 77, 88]
  let sc = span_context(trace_id, span_id, 1)
  
  let is_valid_1 = sc.is_valid()
  let is_valid_2 = sc.is_valid()
  let is_valid_3 = sc.is_valid()
  
  assert_true(is_valid_1)
  assert_true(is_valid_2)
  assert_true(is_valid_3)
}

test "span_context_hex_output_consistency" {
  let trace_id = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]
  let span_id = [200, 201, 202, 203, 204, 205, 206, 207]
  let sc = span_context(trace_id, span_id, 1)
  
  let hex1 = sc.trace_id_hex()
  let hex2 = sc.trace_id_hex()
  let hex3 = sc.trace_id_hex()
  
  assert_eq(hex1, hex2)
  assert_eq(hex2, hex3)
}

test "span_id_hex_output_consistency" {
  let trace_id = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]
  let span_id = [200, 201, 202, 203, 204, 205, 206, 207]
  let sc = span_context(trace_id, span_id, 1)
  
  let hex1 = sc.span_id_hex()
  let hex2 = sc.span_id_hex()
  let hex3 = sc.span_id_hex()
  
  assert_eq(hex1, hex2)
  assert_eq(hex2, hex3)
}

test "is_sampled_flag_consistency" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 1)
  
  let s1 = sc.is_sampled()
  let s2 = sc.is_sampled()
  let s3 = sc.is_sampled()
  
  assert_true(s1)
  assert_true(s2)
  assert_true(s3)
}

test "span_context_fibonacci_values" {
  let trace_id = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 1, 1, 2]
  let span_id = [3, 5, 8, 13, 21, 34, 55, 89]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "bytes_to_hex_checksum_pattern" {
  let data = [15, 240, 15, 240, 15, 240, 15, 240]
  let result = bytes_to_hex(data)
  assert_eq(result, "0ff00ff00ff00ff0")
}

test "span_context_median_byte_values" {
  let trace_id = [127, 128, 127, 128, 127, 128, 127, 128, 127, 128, 127, 128, 127, 128, 127, 128]
  let span_id = [127, 128, 127, 128, 127, 128, 127, 128]
  let sc = span_context(trace_id, span_id, 127)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "invalid_span_context_immutability" {
  let sc1 = invalid_span_context()
  let sc2 = invalid_span_context()
  
  assert_eq(sc1.trace_flags, sc2.trace_flags)
  assert_eq(sc1.is_valid(), sc2.is_valid())
}

test "span_context_geometric_sequence" {
  let trace_id = [1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128]
  let span_id = [1, 2, 4, 8, 16, 32, 64, 128]
  let sc = span_context(trace_id, span_id, 16)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "bytes_to_hex_mirror_pattern" {
  let data = [1, 2, 3, 4, 4, 3, 2, 1]
  let result = bytes_to_hex(data)
  assert_eq(result, "0102030404030201")
}

test "span_context_arithmetic_sequence" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [170, 180, 190, 200, 210, 220, 230, 240]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "hex_encoding_extreme_nibbles" {
  let data = [0, 15, 240, 255]
  let result = bytes_to_hex(data)
  assert_eq(result, "000ff0ff")
}

test "span_context_flags_bit_shift_patterns" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  
  let sc1 = span_context(trace_id, span_id, 1)
  let sc2 = span_context(trace_id, span_id, 2)
  let sc4 = span_context(trace_id, span_id, 4)
  let sc8 = span_context(trace_id, span_id, 8)
  
  assert_true(sc1.is_sampled())
  assert_false(sc2.is_sampled())
  assert_false(sc4.is_sampled())
  assert_false(sc8.is_sampled())
}

test "is_zero_with_mixed_zeros_and_negatives" {
  let arr = [0, 0, -1, 0]
  assert_false(is_zero(arr))
}

test "span_context_complementary_values" {
  let trace_id = [0, 255, 1, 254, 2, 253, 3, 252, 4, 251, 5, 250, 6, 249, 7, 248]
  let span_id = [8, 247, 9, 246, 10, 245, 11, 244]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "bytes_to_hex_xor_pattern" {
  let data = [85, 170, 85, 170, 85, 170, 85, 170]
  let result = bytes_to_hex(data)
  assert_eq(result, "55aa55aa55aa55aa")
}

test "span_context_prime_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  
  let sc2 = span_context(trace_id, span_id, 2)
  let sc3 = span_context(trace_id, span_id, 3)
  let sc5 = span_context(trace_id, span_id, 5)
  let sc7 = span_context(trace_id, span_id, 7)
  
  assert_false(sc2.is_sampled())
  assert_true(sc3.is_sampled())
  assert_true(sc5.is_sampled())
  assert_true(sc7.is_sampled())
}

test "invalid_context_trace_id_structure" {
  let sc = invalid_span_context()
  let tid = sc.trace_id
  
  assert_eq(tid.length(), 16)
  let mut all_zero = true
  let mut i = 0
  while i < 16 {
    if tid[i] != 0 {
      all_zero = false
    }
    i = i + 1
  }
  assert_true(all_zero)
}

test "invalid_context_span_id_structure" {
  let sc = invalid_span_context()
  let sid = sc.span_id
  
  assert_eq(sid.length(), 8)
  let mut all_zero = true
  let mut i = 0
  while i < 8 {
    if sid[i] != 0 {
      all_zero = false
    }
    i = i + 1
  }
  assert_true(all_zero)
}

test "span_context_bcd_values" {
  let trace_id = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8]
  let span_id = [9, 9, 10, 10, 11, 11, 12, 12]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "bytes_to_hex_gray_code" {
  let data = [0, 1, 3, 2, 6, 7, 5, 4]
  let result = bytes_to_hex(data)
  assert_eq(result, "0001030206070504")
}

test "span_context_modular_arithmetic" {
  let trace_id = [11, 22, 33, 44, 55, 66, 77, 88, 99, 110, 121, 132, 143, 154, 165, 176]
  let span_id = [187, 198, 209, 220, 231, 242, 253, 8]
  let sc = span_context(trace_id, span_id, 11)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "hex_encoding_double_digit_hex" {
  let data = [16, 32, 48, 64]
  let result = bytes_to_hex(data)
  assert_eq(result, "10203040")
}

test "span_context_square_numbers" {
  let trace_id = [1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225, 1]
  let span_id = [4, 9, 16, 25, 36, 49, 64, 81]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "bytes_to_hex_cube_numbers" {
  let data = [1, 8, 27, 64]
  let result = bytes_to_hex(data)
  assert_eq(result, "01081b40")
}
