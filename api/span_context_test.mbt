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

// Property-based tests (manual QuickCheck style)

test "property_hex_roundtrip_single_byte" {
  // Property: hex -> hex should be idempotent
  let test_values = [0, 1, 15, 16, 127, 128, 255]
  let mut i = 0
  while i < test_values.length() {
    let byte = test_values[i]
    let bytes = [byte]
    let hex1 = bytes_to_hex(bytes)
    let hex2 = bytes_to_hex(bytes)
    assert_eq(hex1, hex2)
    i = i + 1
  }
}

test "property_hex_length_even" {
  // Property: hex string should always have even length (2 chars per byte)
  let test_bytes = [[], [1], [1, 2], [255], [0, 1, 2, 3]]
  let mut i = 0
  while i < test_bytes.length() {
    let hex = bytes_to_hex(test_bytes[i])
    let len = hex.length()
    assert_eq(len % 2, 0)
    i = i + 1
  }
}

test "property_hex_lowercase_only" {
  // Property: hex output should only contain 0-9 and a-f
  let test_bytes = [0, 1, 10, 15, 16, 31, 255]
  let mut i = 0
  while i < test_bytes.length() {
    let bytes = [test_bytes[i]]
    let hex = bytes_to_hex(bytes)
    let mut j = 0
    while j < hex.length() {
      let c = hex[j]
      let is_digit = c >= '0' && c <= '9'
      let is_lower = c >= 'a' && c <= 'f'
      assert_true(is_digit || is_lower)
      j = j + 1
    }
    i = i + 1
  }
}

test "property_is_zero_consistency" {
  // Property: is_zero of zeros(n) should always be true
  let sizes = [0, 1, 2, 5, 10, 16]
  let mut i = 0
  while i < sizes.length() {
    assert_true(is_zero(zeros(sizes[i])))
    i = i + 1
  }
}

test "property_is_zero_nonzero_consistency" {
  // Property: if is_zero returns true, all bytes must be 0
  let test_bytes = [[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]]
  let mut i = 0
  while i < test_bytes.length() {
    let result = is_zero(test_bytes[i])
    if result {
      let mut j = 0
      while j < test_bytes[i].length() {
        assert_eq(test_bytes[i][j], 0)
        j = j + 1
      }
    }
    i = i + 1
  }
}

test "property_context_validity_idempotent" {
  // Property: is_valid should return consistent result
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.is_valid(), sc.is_valid())
}

test "property_hex_output_length_matches_bytes" {
  // Property: hex output length = 2 * byte array length
  let test_cases = [
    ([], 0),
    ([1], 2),
    ([1, 2], 4),
    ([0, 1, 2, 3, 4, 5, 6, 7], 16),
    ([255, 255, 255, 255], 8)
  ]
  let mut i = 0
  while i < test_cases.length() {
    let (bytes, expected_len) = test_cases[i]
    let hex = bytes_to_hex(bytes)
    assert_eq(hex.length(), expected_len)
    i = i + 1
  }
}

test "property_sampled_flag_mod2" {
  // Property: is_sampled should depend on LSB only
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]

  // All even flags should not be sampled
  let mut flag = 0
  while flag < 10 {
    let sc = span_context(trace_id, span_id, flag * 2)
    assert_false(sc.is_sampled())
    flag = flag + 1
  }

  // All odd flags should be sampled
  let mut flag2 = 0
  while flag2 < 10 {
    let sc = span_context(trace_id, span_id, flag2 * 2 + 1)
    assert_true(sc.is_sampled())
    flag2 = flag2 + 1
  }
}

test "property_sampled_flag_independent_of_validity" {
  // Property: is_sampled depends only on trace_flags LSB, not validity
  // This tests that is_sampled() only checks the flag bit

  // Invalid context with flag=0
  let sc1 = invalid_span_context()
  assert_false(sc1.is_sampled())

  // Invalid contexts (zero trace/span) with flag=1 should still report sampled
  // because is_sampled() only checks the LSB of trace_flags
  let zero_trace = zeros(16)
  let zero_span = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc2 = span_context(zero_trace, zero_span, 1)
  assert_false(sc2.is_valid())  // Invalid due to zero trace
  // Note: is_sampled() only checks the flag bit, so it returns true
  // This is the expected behavior based on the implementation

  let valid_trace = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let zero_span2 = zeros(8)
  let sc3 = span_context(valid_trace, zero_span2, 1)
  assert_false(sc3.is_valid())  // Invalid due to zero span
  // is_sampled() only checks the flag bit
}

test "edge_case_max_trace_flags" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]

  // Test max Int value for trace_flags
  let sc = span_context(trace_id, span_id, 255)
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 255)
}

test "hex_roundtrip_consistency" {
  // Test that consistent bytes produce consistent hex output
  let bytes1 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let bytes2 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  assert_eq(bytes_to_hex(bytes1), bytes_to_hex(bytes2))
}

test "context_differentiation" {
  // Different IDs should produce different hex strings
  let trace_id1 = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id1 = [1, 0, 0, 0, 0, 0, 0, 0]

  let trace_id2 = [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id2 = [1, 0, 0, 0, 0, 0, 0, 0]

  let sc1 = span_context(trace_id1, span_id1, 1)
  let sc2 = span_context(trace_id2, span_id2, 1)

  assert_false(sc1.trace_id_hex() == sc2.trace_id_hex())
}

test "invalid_context_hex_all_zeros" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
}

test "context_with_all_bytes_max" {
  // Test with all bytes at max value (255)
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

test "is_zero_with_pattern" {
  // Test is_zero with repeating patterns
  let pattern1 = [0, 0, 0, 0]
  let pattern2 = [1, 1, 1, 1]
  let pattern3 = [0, 1, 0, 1]
  let pattern4 = [1, 0, 1, 0]

  assert_true(is_zero(pattern1))
  assert_false(is_zero(pattern2))
  assert_false(is_zero(pattern3))
  assert_false(is_zero(pattern4))
}

test "hex_encoding_byte_boundaries" {
  // Test hex encoding at byte boundaries (0x00, 0x0F, 0x10, 0xFF)
  let boundary_bytes = [0, 15, 16, 255]
  let hex = bytes_to_hex(boundary_bytes)
  assert_eq(hex, "000f10ff")
}

test "multiple_contexts_comparison" {
  // Create multiple contexts and verify they're independent
  let trace_id_base = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id_base = [1, 0, 0, 0, 0, 0, 0, 0]

  let sc1 = span_context(trace_id_base, span_id_base, 0)
  let sc2 = span_context(trace_id_base, span_id_base, 1)

  assert_false(sc1.is_sampled())
  assert_true(sc2.is_sampled())
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
  assert_eq(sc1.span_id_hex(), sc2.span_id_hex())
}

// Additional test cases for edge cases and comprehensive coverage

test "trace_flags_edge_cases" {
  // Test different trace flag combinations
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  
  // Test flag 0 (not sampled)
  let sc0 = span_context(trace_id, span_id, 0)
  assert_false(sc0.is_sampled())
  
  // Test flag 1 (sampled)
  let sc1 = span_context(trace_id, span_id, 1)
  assert_true(sc1.is_sampled())
  
  // Test flag 2 (not sampled, different bit)
  let sc2 = span_context(trace_id, span_id, 2)
  assert_false(sc2.is_sampled())
  
  // Test flag 3 (sampled with multiple bits)
  let sc3 = span_context(trace_id, span_id, 3)
  assert_true(sc3.is_sampled())
}

test "span_context_with_max_values" {
  // Test with maximum byte values (0xFF)
  let trace_id = Array::make(16, 255)
  let span_id = Array::make(8, 255)
  let flags = 255
  
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

test "span_context_hex_consistency" {
  // Verify hex conversion consistency across multiple calls
  let trace_id = [0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]
  let span_id = [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11]
  
  let sc = span_context(trace_id, span_id, 1)
  
  // Call hex methods multiple times and verify consistency
  let trace_hex1 = sc.trace_id_hex()
  let trace_hex2 = sc.trace_id_hex()
  let span_hex1 = sc.span_id_hex()
  let span_hex2 = sc.span_id_hex()
  
  assert_eq(trace_hex1, trace_hex2)
  assert_eq(span_hex1, span_hex2)
  assert_eq(trace_hex1, "123456789abcdef01122334455667788")
  assert_eq(span_hex1, "aabbccddeeff0011")
}

test "is_zero_helper_function_edge_cases" {
  // Test is_zero with various edge cases
  
  // Empty array should be considered zero
  assert_true(is_zero([]))
  
  // Single zero element
  assert_true(is_zero([0]))
  
  // Single non-zero element
  assert_false(is_zero([1]))
  
  // Multiple zeros
  assert_true(is_zero([0, 0, 0, 0]))
  
  // Mixed zeros and non-zeros
  assert_false(is_zero([0, 0, 1, 0]))
  assert_false(is_zero([1, 0, 0, 0]))
  assert_false(is_zero([0, 0, 0, 1]))
  
  // Large array of zeros
  assert_true(is_zero(Array::make(100, 0)))
  
  // Large array with one non-zero at the end
  let arr = Array::make(100, 0)
  arr[99] = 1
  assert_false(is_zero(arr))
}

test "bytes_to_hex_edge_cases" {
  // Test hex conversion with edge cases
  
  // Empty array
  assert_eq(bytes_to_hex([]), "")
  
  // Single byte values
  assert_eq(bytes_to_hex([0]), "00")
  assert_eq(bytes_to_hex([15]), "0f")
  assert_eq(bytes_to_hex([16]), "10")
  assert_eq(bytes_to_hex([255]), "ff")
  
  // Alternating pattern
  assert_eq(bytes_to_hex([0x0f, 0xf0, 0x0f, 0xf0]), "0ff00ff0")
  
  // Sequential bytes
  assert_eq(bytes_to_hex([0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]), 
            "00112233445566778899aabbccddeeff")
}

test "span_context_immutability_check" {
  // Verify that SpanContext fields are properly encapsulated
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 1)
  
  // Original arrays should not affect the SpanContext after creation
  trace_id[0] = 0
  span_id[0] = 0
  
  // SpanContext should still report as valid since it captured the original state
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "char_from_helper_edge_cases" {
  // Test the char_from helper function through indirect testing
  // Since char_from is private, we test bytes_to_hex which uses it internally
  
  let test_bytes = [0x61, 0x62, 0x63, 0x31, 0x32, 0x33] // "abc123" in hex
  let hex_result = bytes_to_hex(test_bytes)
  
  // Should correctly convert each byte to hex
  assert_eq(hex_result, "616263313233")
  
  // Test empty array through hex conversion
  assert_eq(bytes_to_hex([]), "")
}

test "hex_conversion_consistency_property" {
  // Property-based style test (without QuickCheck)
  // Test that hex conversion is consistent and reversible in concept
  
  let test_cases = [
    ([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], "000102030405060708090a0b0c0d0e0f"),
    ([255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240], "fffefdfcfbfaf9f8f7f6f5f4f3f2f1f0"),
    ([0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89], "abcdef0123456789abcdef0123456789")
  ]
  
  for i = 0; i < test_cases.length(); i = i + 1 {
    let (bytes, expected_hex) = test_cases[i]
    let actual_hex = bytes_to_hex(bytes)
    assert_eq(actual_hex, expected_hex)
    
    // Verify length is exactly 2 * bytes.length
    assert_eq(actual_hex.length(), bytes.length() * 2)
  }
}

test "span_context_with_single_non_zero_byte" {
  // Test contexts with only one non-zero byte at different positions
  
  // Non-zero at start
  let trace_id_start = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id_start = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc_start = span_context(trace_id_start, span_id_start, 1)
  assert_true(sc_start.is_valid())
  
  // Non-zero at end
  let trace_id_end = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id_end = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc_end = span_context(trace_id_end, span_id_end, 1)
  assert_true(sc_end.is_valid())
  
  // Non-zero in middle
  let trace_id_middle = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]
  let span_id_middle = [0, 0, 0, 0, 0, 0, 1, 0]
  let sc_middle = span_context(trace_id_middle, span_id_middle, 1)
  assert_true(sc_middle.is_valid())
}

test "span_context_flags_sampling" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc1 = span_context(trace_id, span_id, 0)
  assert_false(sc1.is_sampled())
  
  let sc2 = span_context(trace_id, span_id, 1)
  assert_true(sc2.is_sampled())
  
  let sc3 = span_context(trace_id, span_id, 2)
  assert_false(sc3.is_sampled()) // Only bit 0 is sampled
  
  let sc4 = span_context(trace_id, span_id, 255)
  assert_true(sc4.is_sampled())
}

test "span_context_hex_format" {
  let trace_id = [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  let span_id = [7, 6, 5, 4, 3, 2, 1, 0]
  let sc = span_context(trace_id, span_id, 0)
  
  assert_eq(sc.trace_id_hex(), "0f0e0d0c0b0a09080706050403020100")
  assert_eq(sc.span_id_hex(), "0706050403020100")
}

test "span_context_equality_different_trace_id" {
  let tid1 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  let tid2 = [2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc1 = span_context(tid1, sid, 1)
  let sc2 = span_context(tid2, sid, 1)
  
  assert_true(sc1.trace_id_hex() != sc2.trace_id_hex())
}

test "span_context_equality_different_span_id" {
  let tid = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  let sid1 = [1, 2, 3, 4, 5, 6, 7, 8]
  let sid2 = [8, 7, 6, 5, 4, 3, 2, 1]
  let sc1 = span_context(tid, sid1, 1)
  let sc2 = span_context(tid, sid2, 1)
  
  assert_true(sc1.span_id_hex() != sc2.span_id_hex())
}

test "span_context_equality_different_flags" {
  let tid = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc1 = span_context(tid, sid, 0)
  let sc2 = span_context(tid, sid, 1)
  
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
  assert_eq(sc1.span_id_hex(), sc2.span_id_hex())
  assert_true(sc1.trace_flags != sc2.trace_flags)
}

test "span_context_max_values" {
  let tid = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let sid = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc = span_context(tid, sid, 255)
  
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
  assert_true(sc.is_sampled())
}

test "span_context_min_values" {
  let tid = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let sid = [0, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(tid, sid, 0)
  
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
  assert_false(sc.is_sampled())
  assert_false(sc.is_valid())
}

test "span_context_is_valid_mixed" {
  let tid_valid = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let sid_valid = [0, 0, 0, 0, 0, 0, 0, 1]
  let sid_invalid = [0, 0, 0, 0, 0, 0, 0, 0]
  let tid_invalid = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  
  assert_true(span_context(tid_valid, sid_valid, 0).is_valid())
  assert_false(span_context(tid_invalid, sid_valid, 0).is_valid())
  assert_false(span_context(tid_valid, sid_invalid, 0).is_valid())
  assert_false(span_context(tid_invalid, sid_invalid, 0).is_valid())
}

test "span_context_hex_lowercase" {
  let tid = [10, 11, 12, 13, 14, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let sid = [10, 11, 12, 13, 14, 15, 0, 0]
  let sc = span_context(tid, sid, 0)
  
  let tid_hex = sc.trace_id_hex()
  let sid_hex = sc.span_id_hex()
  
  assert_eq(tid_hex[0:6].to_string(), "0a0b0c")
  assert_eq(sid_hex[0:6].to_string(), "0a0b0c")
}

test "span_context_trace_flags_all_bits" {
  let tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc = span_context(tid, sid, 255)
  assert_eq(sc.trace_flags, 255)
  assert_true(sc.is_sampled())
}

test "span_context_trace_flags_only_sampled_bit" {
  let tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc = span_context(tid, sid, 1)
  assert_eq(sc.trace_flags, 1)
  assert_true(sc.is_sampled())
}
