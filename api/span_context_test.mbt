// Internal tests for SpanContext

// Helper to create zero-filled array of given length
fn zeros(n : Int) -> Array[Int] {
  Array::make(n, 0)
}

test "invalid_span_context" {
  let sc = invalid_span_context()
  assert_false(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "invalid_span_context_trace_id_zero" {
  let sc = invalid_span_context()
  let tid = sc.trace_id
  assert_eq(tid.length(), 16)
  let mut i = 0
  while i < 16 {
    assert_eq(tid[i], 0)
    i = i + 1
  }
}

test "invalid_span_context_span_id_zero" {
  let sc = invalid_span_context()
  let sid = sc.span_id
  assert_eq(sid.length(), 8)
  let mut i = 0
  while i < 8 {
    assert_eq(sid[i], 0)
    i = i + 1
  }
}

test "invalid_span_context_flags_zero" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_flags, 0)
}

test "valid_span_context" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let flags = 1
  
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "not_sampled_span_context" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let flags = 0
  
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "zero_trace_id_invalid" {
  let trace_id = zeros(16)
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let flags = 1
  
  let sc = span_context(trace_id, span_id, flags)
  assert_false(sc.is_valid())
}

test "zero_span_id_invalid" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = zeros(8)
  let flags = 1
  
  let sc = span_context(trace_id, span_id, flags)
  assert_false(sc.is_valid())
}

test "trace_id_hex" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  
  let sc = span_context(trace_id, span_id, 1)
  let hex = sc.trace_id_hex()
  
  // Expected: "000102030405060708090a0b0c0d0e0f"
  assert_eq(hex.length(), 32)
}

test "span_id_hex" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  
  let sc = span_context(trace_id, span_id, 1)
  let hex = sc.span_id_hex()
  
  // Expected: "1011121314151617"
  assert_eq(hex.length(), 16)
}

test "sampled_flag" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  
  // Test with sampled bit set
  let sc1 = span_context(trace_id, span_id, 1)
  assert_true(sc1.is_sampled())
  
  // Test with sampled bit not set
  let sc2 = span_context(trace_id, span_id, 0)
  assert_false(sc2.is_sampled())
  
  // Test with multiple bits set
  let sc3 = span_context(trace_id, span_id, 255)
  assert_true(sc3.is_sampled())
}

test "trace_id_hex_correctness" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  
  let sc = span_context(trace_id, span_id, 1)
  let hex = sc.trace_id_hex()
  
  // Expected: "000102030405060708090a0b0c0d0e0f"
  assert_eq(hex, "000102030405060708090a0b0c0d0e0f")
}

test "span_id_hex_correctness" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  
  let sc = span_context(trace_id, span_id, 1)
  let hex = sc.span_id_hex()
  
  // Expected: "1011121314151617"
  assert_eq(hex, "1011121314151617")
}

test "max_byte_values" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

test "is_zero_helper" {
  // Test with all zeros
  let zeros = [0, 0, 0, 0]
  assert_true(is_zero(zeros))
  
  // Test with non-zero values
  let non_zeros = [0, 1, 0, 0]
  assert_false(is_zero(non_zeros))
  
  // Test with empty array
  let empty : Array[Int] = []
  assert_true(is_zero(empty))
}

test "bytes_to_hex_helper" {
  // Test with simple values
  let simple = [0, 1, 15, 16, 255]
  assert_eq(bytes_to_hex(simple), "00010f10ff")

  // Test with empty array
  let empty : Array[Int] = []
  assert_eq(bytes_to_hex(empty), "")
}

test "is_zero_single_nonzero" {
  // Test with last byte non-zero
  let arr = [0, 0, 0, 1]
  assert_false(is_zero(arr))
}

test "bytes_to_hex_all_zeros" {
  let zeros = [0, 0, 0, 0, 0]
  assert_eq(bytes_to_hex(zeros), "0000000000")
}

test "bytes_to_hex_alternating" {
  let alt = [170, 85, 170, 85]
  assert_eq(bytes_to_hex(alt), "aa55aa55")
}

test "trace_flags_bit2" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  // Bit 2 set (4), sampled bit (1) not set
  let sc = span_context(trace_id, span_id, 4)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "minimum_nonzero_context" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_id_hex(), "01000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0100000000000000")
}

// Additional comprehensive tests

test "trace_id_length_validation_short" {
  let trace_id = [1, 2, 3]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "trace_id_length_validation_long" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_id_length_validation_short" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_id_length_validation_long" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8, 9]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "hex_encoding_special_bytes" {
  let trace_id = [0, 15, 16, 31, 32, 63, 64, 127, 128, 191, 192, 223, 224, 239, 240, 255]
  let span_id = [0, 15, 127, 128, 192, 224, 240, 255]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.trace_id_hex(), "000f101f203f407f80bfc0dfe0eff0ff")
  assert_eq(sc.span_id_hex(), "000f7f80c0e0f0ff")
}

test "trace_flags_all_bits" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 255)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 255)
}

test "trace_flags_only_sampled" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 1)
}

test "trace_flags_even_value" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 2)
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 2)
}

test "trace_flags_odd_value" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 3)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 3)
}

test "trace_id_hex_padding" {
  let trace_id = [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.trace_id_hex(), "00000001000000000000000000000000")
}

test "span_id_hex_padding" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 1, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.span_id_hex(), "0000000100000000")
}

test "is_zero_multiple_nonzero" {
  let arr = [1, 2, 3, 4]
  assert_false(is_zero(arr))
}

test "is_zero_large_array" {
  let zeros = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_true(is_zero(zeros))
}

test "bytes_to_hex_single_byte" {
  let single = [42]
  assert_eq(bytes_to_hex(single), "2a")
}

test "bytes_to_hex_large_values" {
  let large = [200, 201, 202, 203, 204]
  assert_eq(bytes_to_hex(large), "c8c9cacbcc")
}

test "random_valid_context_1" {
  let trace_id = [23, 45, 67, 89, 12, 34, 56, 78, 90, 11, 22, 33, 44, 55, 66, 77]
  let span_id = [88, 99, 111, 123, 135, 147, 159, 171]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "random_valid_context_2" {
  let trace_id = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]
  let span_id = [200, 201, 202, 203, 204, 205, 206, 207]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "sequential_trace_id" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [0, 1, 2, 3, 4, 5, 6, 7]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "000102030405060708090a0b0c0d0e0f")
  assert_eq(sc.span_id_hex(), "0001020304050607")
}

test "descending_values" {
  let trace_id = [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  let span_id = [7, 6, 5, 4, 3, 2, 1, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "power_of_two_values" {
  let trace_id = [1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128]
  let span_id = [1, 2, 4, 8, 16, 32, 64, 128]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "01020408102040800102040810204080")
}

test "mixed_zero_nonzero_trace_id" {
  let trace_id = [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "mixed_zero_nonzero_span_id" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 1, 0, 1, 0, 1, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "last_byte_only_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000001")
}

test "last_byte_only_span_id" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0000000000000001")
}

test "middle_byte_nonzero_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000ff0000000000000000")
}

test "middle_byte_nonzero_span_id" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 255, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "000000ff00000000")
}

test "trace_flags_large_value" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 127)
  assert_true(sc.is_sampled())
}

test "trace_flags_negative_like" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 254)
  assert_false(sc.is_sampled())
}

test "hex_all_different_values" {
  let bytes = [0, 17, 34, 51, 68, 85, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "00112233445566778899aabbccddeeff")
}

test "bytes_to_hex_mirror" {
  let bytes = [1, 2, 3, 3, 2, 1]
  assert_eq(bytes_to_hex(bytes), "010203030201")
}

test "is_zero_prefix_zeros" {
  let arr = [0, 0, 0, 1, 2, 3]
  assert_false(is_zero(arr))
}

test "is_zero_suffix_zeros" {
  let arr = [1, 2, 3, 0, 0, 0]
  assert_false(is_zero(arr))
}

test "context_immutability_check" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc1 = span_context(trace_id, span_id, 1)
  let sc2 = span_context(trace_id, span_id, 1)
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
  assert_eq(sc1.span_id_hex(), sc2.span_id_hex())
}

test "invalid_span_context_always_invalid" {
  let sc1 = invalid_span_context()
  let sc2 = invalid_span_context()
  assert_false(sc1.is_valid())
  assert_false(sc2.is_valid())
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
}

test "hex_lowercase_check" {
  let trace_id = [171, 205, 239, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  let hex = sc.trace_id_hex()
  assert_eq(hex[0:2].to_string(), "ab")
  assert_eq(hex[2:4].to_string(), "cd")
  assert_eq(hex[4:6].to_string(), "ef")
}

test "boundary_byte_values_trace" {
  let trace_id = [0, 1, 127, 128, 254, 255, 0, 1, 127, 128, 254, 255, 0, 1, 254, 255]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "boundary_byte_values_span" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 1, 127, 128, 254, 255, 0, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "repeated_pattern_trace" {
  let trace_id = [170, 170, 170, 170, 170, 170, 170, 170, 170, 170, 170, 170, 170, 170, 170, 170]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
}

test "repeated_pattern_span" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [85, 85, 85, 85, 85, 85, 85, 85]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "5555555555555555")
}

test "alternating_bits_trace" {
  let trace_id = [170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "alternating_bits_span" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [170, 85, 170, 85, 170, 85, 170, 85]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "fibonacci_like_sequence" {
  let trace_id = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 1, 1, 2]
  let span_id = [1, 1, 2, 3, 5, 8, 13, 21]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "prime_numbers_sequence" {
  let trace_id = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53]
  let span_id = [2, 3, 5, 7, 11, 13, 17, 19]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "sampled_flag_bit_position" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  
  let sc0 = span_context(trace_id, span_id, 0)
  assert_false(sc0.is_sampled())
  
  let sc1 = span_context(trace_id, span_id, 1)
  assert_true(sc1.is_sampled())
  
  let sc2 = span_context(trace_id, span_id, 2)
  assert_false(sc2.is_sampled())
  
  let sc3 = span_context(trace_id, span_id, 3)
  assert_true(sc3.is_sampled())
}

test "hex_length_consistency" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.trace_id_hex().length(), 32)
  assert_eq(sc.span_id_hex().length(), 16)
}

test "empty_arrays_invalid" {
  let trace_id : Array[Int] = []
  let span_id : Array[Int] = []
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "single_nonzero_byte_contexts" {
  let mut i = 0
  while i < 16 {
    let trace_id = Array::make(16, 0)
    trace_id[i] = 1
    let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
    let sc = span_context(trace_id, span_id, 1)
    assert_true(sc.is_valid())
    i = i + 1
  }
}

test "single_nonzero_byte_span_contexts" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let mut i = 0
  while i < 8 {
    let span_id = Array::make(8, 0)
    span_id[i] = 1
    let sc = span_context(trace_id, span_id, 1)
    assert_true(sc.is_valid())
    i = i + 1
  }
}

test "trace_flags_powers_of_two" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  
  let sc1 = span_context(trace_id, span_id, 1)
  assert_true(sc1.is_sampled())
  
  let sc2 = span_context(trace_id, span_id, 2)
  assert_false(sc2.is_sampled())
  
  let sc4 = span_context(trace_id, span_id, 4)
  assert_false(sc4.is_sampled())
  
  let sc8 = span_context(trace_id, span_id, 8)
  assert_false(sc8.is_sampled())
}
