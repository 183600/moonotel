// Extended scenario tests for edge cases and combinations

test "trace_id_with_sequential_powers_of_2" {
  let trace_id = [1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128]
  let span_id = [1, 1, 1, 1, 1, 1, 1, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "span_id_with_prime_numbers" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [2, 3, 5, 7, 11, 13, 17, 19]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "trace_id_fibonacci_like" {
  let trace_id = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 255, 255, 255]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_with_all_low_nibble_f" {
  let trace_id = [15, 31, 47, 63, 79, 95, 111, 127, 143, 159, 175, 191, 207, 223, 239, 255]
  let span_id = [15, 31, 47, 63, 79, 95, 111, 127]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_with_all_high_nibble_f" {
  let trace_id = [240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255]
  let span_id = [240, 241, 242, 243, 244, 245, 246, 247]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "trace_flags_powers_of_2" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc1 = span_context(trace_id, span_id, 1)
  assert_true(sc1.is_sampled())
  
  let sc2 = span_context(trace_id, span_id, 2)
  assert_false(sc2.is_sampled())
  
  let sc4 = span_context(trace_id, span_id, 4)
  assert_false(sc4.is_sampled())
  
  let sc8 = span_context(trace_id, span_id, 8)
  assert_false(sc8.is_sampled())
  
  let sc16 = span_context(trace_id, span_id, 16)
  assert_false(sc16.is_sampled())
}

test "trace_flags_combined_bits" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc5 = span_context(trace_id, span_id, 5)
  assert_true(sc5.is_sampled())
  
  let sc7 = span_context(trace_id, span_id, 7)
  assert_true(sc7.is_sampled())
  
  let sc15 = span_context(trace_id, span_id, 15)
  assert_true(sc15.is_sampled())
}

test "hex_encoding_nibble_boundaries" {
  let bytes = [0, 15, 16, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "000f10ff")
}

test "hex_encoding_ascending_sequence" {
  let bytes = [32, 33, 34, 35, 36, 37, 38, 39]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "2021222324252627")
}

test "hex_encoding_descending_sequence" {
  let bytes = [39, 38, 37, 36, 35, 34, 33, 32]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "2726252423222120")
}

test "is_zero_with_max_int_values" {
  let arr = [255, 255, 255, 255]
  assert_false(is_zero(arr))
}

test "is_zero_with_single_255" {
  let arr = [0, 0, 0, 255]
  assert_false(is_zero(arr))
}

test "span_context_trace_id_length_15" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_trace_id_length_17" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_span_id_length_7" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_span_id_length_9" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8, 9]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_both_max_length" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 255)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_flags, 255)
}

test "multiple_contexts_independence" {
  let trace_id1 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id1 = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc1 = span_context(trace_id1, span_id1, 1)
  
  let trace_id2 = [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  let span_id2 = [8, 7, 6, 5, 4, 3, 2, 1]
  let sc2 = span_context(trace_id2, span_id2, 0)
  
  assert_true(sc1.is_valid())
  assert_true(sc2.is_valid())
  assert_true(sc1.is_sampled())
  assert_false(sc2.is_sampled())
}

test "hex_output_deterministic" {
  let trace_id = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]
  let span_id = [50, 51, 52, 53, 54, 55, 56, 57]
  let sc1 = span_context(trace_id, span_id, 1)
  let sc2 = span_context(trace_id, span_id, 1)
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
  assert_eq(sc1.span_id_hex(), sc2.span_id_hex())
}

test "bytes_to_hex_symmetry" {
  let bytes1 = [1, 2, 3, 4, 5]
  let bytes2 = [5, 4, 3, 2, 1]
  let hex1 = bytes_to_hex(bytes1)
  let hex2 = bytes_to_hex(bytes2)
  assert_eq(hex1.length(), hex2.length())
}

test "trace_id_first_byte_nonzero" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "trace_id_middle_byte_nonzero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "trace_id_last_byte_nonzero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_id_first_byte_nonzero" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_id_middle_byte_nonzero" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 1, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_id_last_byte_nonzero" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "bytes_to_hex_repeated_bytes" {
  let bytes = [100, 100, 100, 100]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "64646464")
}

test "bytes_to_hex_palindrome" {
  let bytes = [1, 2, 3, 2, 1]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0102030201")
}

test "is_zero_alternating_pattern_with_zero" {
  let arr = [0, 1, 0, 1, 0, 1]
  assert_false(is_zero(arr))
}

test "context_validity_with_minimal_nonzero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "context_validity_with_maximal_values" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc = span_context(trace_id, span_id, 255)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "hex_encoding_mixed_high_low" {
  let bytes = [15, 240, 15, 240]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0ff00ff0")
}

test "hex_encoding_byte_128" {
  let bytes = [128, 128, 128, 128]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "80808080")
}

test "hex_encoding_byte_64" {
  let bytes = [64, 64, 64, 64]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "40404040")
}

test "hex_encoding_byte_32" {
  let bytes = [32, 32, 32, 32]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "20202020")
}

test "trace_flags_bitwise_patterns" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc_129 = span_context(trace_id, span_id, 129)
  assert_true(sc_129.is_sampled())
  
  let sc_128 = span_context(trace_id, span_id, 128)
  assert_false(sc_128.is_sampled())
}

test "span_context_creation_consistency" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [11, 22, 33, 44, 55, 66, 77, 88]
  
  let sc1 = span_context(trace_id, span_id, 1)
  let sc2 = span_context(trace_id, span_id, 1)
  let sc3 = span_context(trace_id, span_id, 1)
  
  assert_eq(sc1.is_valid(), sc2.is_valid())
  assert_eq(sc2.is_valid(), sc3.is_valid())
  assert_eq(sc1.is_sampled(), sc2.is_sampled())
  assert_eq(sc2.is_sampled(), sc3.is_sampled())
}

test "invalid_context_hex_consistency" {
  let sc1 = invalid_span_context()
  let sc2 = invalid_span_context()
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
  assert_eq(sc1.span_id_hex(), sc2.span_id_hex())
}

test "bytes_to_hex_incremental_values" {
  let bytes = [50, 51, 52, 53, 54, 55, 56, 57, 58, 59]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "32333435363738393a3b")
}

test "is_zero_boundary_test_16_bytes" {
  let zeros = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_true(is_zero(zeros))
  
  let nonzeros = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  assert_false(is_zero(nonzeros))
}

test "is_zero_boundary_test_8_bytes" {
  let zeros = [0, 0, 0, 0, 0, 0, 0, 0]
  assert_true(is_zero(zeros))
  
  let nonzeros = [0, 0, 0, 0, 0, 0, 0, 1]
  assert_false(is_zero(nonzeros))
}

test "span_context_with_specific_hex_pattern_1" {
  let trace_id = [0xde, 0xad, 0xbe, 0xef, 0xca, 0xfe, 0xba, 0xbe, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_with_specific_hex_pattern_2" {
  let trace_id = [0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89]
  let span_id = [0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}
