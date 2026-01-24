// Corner cases and boundary condition tests

test "trace_id_single_bit_patterns_bit_0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "01000000000000000000000000000000")
}

test "trace_id_single_bit_patterns_bit_7" {
  let trace_id = [128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "80000000000000000000000000000000")
}

test "span_id_single_bit_patterns_bit_0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0100000000000000")
}

test "span_id_single_bit_patterns_bit_7" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [128, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "8000000000000000")
}

test "byte_to_hex_char_range_0_to_9" {
  let mut i = 0
  while i <= 9 {
    let hex = byte_to_hex_char(i)
    assert_eq(hex.length(), 1)
    i = i + 1
  }
}

test "byte_to_hex_char_range_10_to_15" {
  let mut i = 10
  while i <= 15 {
    let hex = byte_to_hex_char(i)
    assert_eq(hex.length(), 1)
    i = i + 1
  }
}

test "hex_encoding_all_bytes_0_to_15" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "000102030405060708090a0b0c0d0e0f")
  assert_eq(hex.length(), 32)
}

test "hex_encoding_all_bytes_240_to_255" {
  let bytes = [240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
  assert_eq(hex.length(), 32)
}

test "span_context_flags_range_0_to_10" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let mut i = 0
  while i <= 10 {
    let sc = span_context(trace_id, span_id, i)
    assert_true(sc.is_valid())
    if i % 2 == 1 {
      assert_true(sc.is_sampled())
    } else {
      assert_false(sc.is_sampled())
    }
    i = i + 1
  }
}

test "invalid_context_all_properties" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_id.length(), 16)
  assert_eq(sc.span_id.length(), 8)
  assert_eq(sc.trace_flags, 0)
  assert_false(sc.is_valid())
  assert_false(sc.is_sampled())
  assert_true(is_zero(sc.trace_id))
  assert_true(is_zero(sc.span_id))
}

test "valid_context_minimal_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000001")
}

test "valid_context_minimal_span_id" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0000000000000001")
}

test "hex_lowercase_verification_a_to_f" {
  let bytes = [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "aabbccddeeff")
}

test "bytes_to_hex_two_bytes" {
  let bytes = [0, 255]
  assert_eq(bytes_to_hex(bytes), "00ff")
}

test "bytes_to_hex_three_bytes" {
  let bytes = [0, 128, 255]
  assert_eq(bytes_to_hex(bytes), "0080ff")
}

test "bytes_to_hex_four_bytes" {
  let bytes = [0, 64, 128, 255]
  assert_eq(bytes_to_hex(bytes), "004080ff")
}

test "is_zero_stress_large_array" {
  let zeros = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_true(is_zero(zeros))
}

test "is_zero_stress_large_array_with_nonzero" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  assert_false(is_zero(arr))
}

test "trace_id_multiple_nonzero_bytes_pattern_1" {
  let trace_id = [1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "trace_id_multiple_nonzero_bytes_pattern_2" {
  let trace_id = [0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_id_multiple_nonzero_bytes_pattern_1" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 0, 2, 0, 3, 0, 4, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_id_multiple_nonzero_bytes_pattern_2" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 1, 0, 2, 0, 3, 0, 4]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "trace_flags_specific_combinations" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc_13 = span_context(trace_id, span_id, 13)
  assert_true(sc_13.is_sampled())
  
  let sc_12 = span_context(trace_id, span_id, 12)
  assert_false(sc_12.is_sampled())
  
  let sc_31 = span_context(trace_id, span_id, 31)
  assert_true(sc_31.is_sampled())
  
  let sc_30 = span_context(trace_id, span_id, 30)
  assert_false(sc_30.is_sampled())
}

test "hex_encoding_nibble_split" {
  let bytes = [0x01, 0x10]
  assert_eq(bytes_to_hex(bytes), "0110")
}

test "hex_encoding_consecutive_bytes" {
  let bytes = [100, 101, 102, 103, 104]
  assert_eq(bytes_to_hex(bytes), "6465666768")
}

test "span_context_different_flags_same_ids" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [11, 22, 33, 44, 55, 66, 77, 88]
  
  let sc0 = span_context(trace_id, span_id, 0)
  let sc1 = span_context(trace_id, span_id, 1)
  let sc2 = span_context(trace_id, span_id, 2)
  let sc3 = span_context(trace_id, span_id, 3)
  
  assert_eq(sc0.trace_id_hex(), sc1.trace_id_hex())
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
  assert_eq(sc2.trace_id_hex(), sc3.trace_id_hex())
  
  assert_eq(sc0.span_id_hex(), sc1.span_id_hex())
  assert_eq(sc1.span_id_hex(), sc2.span_id_hex())
  assert_eq(sc2.span_id_hex(), sc3.span_id_hex())
}

test "bytes_to_hex_special_boundary_values" {
  let bytes = [1, 15, 16, 127, 128, 254, 255]
  assert_eq(bytes_to_hex(bytes), "010f107f80feff")
}

test "trace_id_hex_output_length" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.trace_id_hex().length(), 32)
}

test "span_id_hex_output_length" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.span_id_hex().length(), 16)
}

test "is_zero_performance_check" {
  let zeros = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let mut i = 0
  while i < 10 {
    assert_true(is_zero(zeros))
    i = i + 1
  }
}

test "bytes_to_hex_performance_check" {
  let bytes = [1, 2, 3, 4, 5, 6, 7, 8]
  let mut i = 0
  while i < 10 {
    let hex = bytes_to_hex(bytes)
    assert_eq(hex, "0102030405060708")
    i = i + 1
  }
}

test "span_context_creation_performance_check" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let mut i = 0
  while i < 10 {
    let sc = span_context(trace_id, span_id, 1)
    assert_true(sc.is_valid())
    i = i + 1
  }
}

test "invalid_span_context_repeated_calls" {
  let mut i = 0
  while i < 5 {
    let sc = invalid_span_context()
    assert_false(sc.is_valid())
    assert_false(sc.is_sampled())
    i = i + 1
  }
}

test "trace_id_with_ascii_range_bytes" {
  let trace_id = [65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80]
  let span_id = [81, 82, 83, 84, 85, 86, 87, 88]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_id_with_printable_ascii_bytes" {
  let trace_id = [32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47]
  let span_id = [48, 49, 50, 51, 52, 53, 54, 55]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "hex_encoding_boundary_0x7f_0x80" {
  let bytes = [127, 128]
  assert_eq(bytes_to_hex(bytes), "7f80")
}

test "hex_encoding_boundary_0xfe_0xff" {
  let bytes = [254, 255]
  assert_eq(bytes_to_hex(bytes), "feff")
}

test "trace_flags_all_bits_except_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 254)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 254)
}

test "span_context_state_immutability" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  
  let hex1 = sc.trace_id_hex()
  let hex2 = sc.trace_id_hex()
  assert_eq(hex1, hex2)
  
  let shex1 = sc.span_id_hex()
  let shex2 = sc.span_id_hex()
  assert_eq(shex1, shex2)
}

test "bytes_to_hex_empty_string" {
  let empty : Array[Int] = []
  assert_eq(bytes_to_hex(empty), "")
}

test "is_zero_verify_loop_behavior" {
  let arr = [0, 0, 0, 0, 1, 0, 0, 0]
  assert_false(is_zero(arr))
}

test "span_context_validation_both_zero_arrays" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_validation_trace_id_zero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_validation_span_id_zero" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}
