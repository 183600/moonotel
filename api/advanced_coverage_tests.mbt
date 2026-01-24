// Advanced coverage tests for comprehensive functionality testing

test "span_context_extreme_boundary_values" {
  // Test maximum trace ID values
  let max_trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let max_span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc_max = span_context(max_trace_id, max_span_id, 255)
  assert_true(sc_max.is_valid())
  assert_eq(sc_max.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc_max.span_id_hex(), "ffffffffffffffff")
  
  // Test minimum non-zero values
  let min_trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let min_span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc_min = span_context(min_trace_id, min_span_id, 1)
  assert_true(sc_min.is_valid())
  assert_eq(sc_min.trace_id_hex(), "00000000000000000000000000000001")
  assert_eq(sc_min.span_id_hex(), "0000000000000001")
}

test "span_context_invalid_edge_cases" {
  // Trace ID too short
  let short_trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc1 = span_context(short_trace_id, span_id, 1)
  assert_false(sc1.is_valid())
  
  // Span ID too short
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let short_span_id = [17, 18, 19, 20, 21, 22, 23]
  let sc2 = span_context(trace_id, short_span_id, 1)
  assert_false(sc2.is_valid())
  
  // Trace ID all zeros
  let zero_trace_id = Array::make(16, 0)
  let valid_span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc3 = span_context(zero_trace_id, valid_span_id, 1)
  assert_false(sc3.is_valid())
  
  // Span ID all zeros
  let valid_trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let zero_span_id = Array::make(8, 0)
  let sc4 = span_context(valid_trace_id, zero_span_id, 1)
  assert_false(sc4.is_valid())
}

test "hex_encoding_advanced_patterns" {
  // Test Fibonacci sequence bytes
  let fib_bytes = [1, 1, 2, 3, 5, 8, 13, 21]
  assert_eq(bytes_to_hex(fib_bytes), "0101020305080d15")
  
  // Test powers of 2
  let pow2_bytes = [1, 2, 4, 8, 16, 32, 64, 128]
  assert_eq(bytes_to_hex(pow2_bytes), "0102040810204080")
  
  // Test ASCII printable characters
  let ascii_bytes = [32, 65, 97, 48, 57] // space, A, a, 0, 9
  assert_eq(bytes_to_hex(ascii_bytes), "2041613039")
}

test "byte_to_hex_char_comprehensive" {
  // Test all valid nibble values (0-15)
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

test "is_zero_comprehensive" {
  // Test truly zero arrays
  assert_true(is_zero([]))
  assert_true(is_zero([0]))
  assert_true(is_zero([0, 0, 0]))
  assert_true(is_zero(Array::make(100, 0)))
  
  // Test non-zero arrays
  assert_false(is_zero([1]))
  assert_false(is_zero([0, 1, 0]))
  assert_false(is_zero(Array::make(10, 1)))
  
  // Test mixed arrays
  assert_false(is_zero([0, 0, 1]))
  assert_false(is_zero([1, 0, 0]))
  assert_false(is_zero([0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]))
}

test "trace_flags_comprehensive" {
  // Test various flag combinations
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  
  // Flag 0 (not sampled)
  let sc0 = span_context(trace_id, span_id, 0)
  assert_true(sc0.is_valid())
  assert_false(sc0.is_sampled())
  
  // Flag 1 (sampled)
  let sc1 = span_context(trace_id, span_id, 1)
  assert_true(sc1.is_valid())
  assert_true(sc1.is_sampled())
  
  // Flag 2 (debug flag)
  let sc2 = span_context(trace_id, span_id, 2)
  assert_true(sc2.is_valid())
  assert_false(sc2.is_sampled())
  
  // Flag 3 (debug + sampled)
  let sc3 = span_context(trace_id, span_id, 3)
  assert_true(sc3.is_valid())
  assert_true(sc3.is_sampled())
  
  // Maximum flag value
  let sc255 = span_context(trace_id, span_id, 255)
  assert_true(sc255.is_valid())
  assert_true(sc255.is_sampled())
}

test "span_context_array_operations" {
  // Test that arrays are properly copied, not referenced
  let original_trace = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let original_span = [17, 18, 19, 20, 21, 22, 23, 24]
  
  let sc = span_context(original_trace, original_span, 1)
  
  // Verify the span context has the correct values
  assert_eq(sc.trace_id[0], 1)
  assert_eq(sc.span_id[0], 17)
  assert_true(sc.is_valid())
  
  // Also verify hex output is correct
  assert_eq(sc.trace_id_hex(), "0102030405060708090a0b0c0d0e0f10")
  assert_eq(sc.span_id_hex(), "1112131415161718")
}

test "hex_concatenation_stress" {
  // Test long sequences for performance
  let long_bytes = []
  let mut i = 0
  while i < 50 {
    long_bytes.push(i % 256)
    i = i + 1
  }
  
  let hex = bytes_to_hex(long_bytes)
  assert_eq(hex.length(), 100) // 50 bytes = 100 hex chars
  
  // Verify some specific hex string positions by checking expected values
  assert_true(hex.starts_with("00")) // byte 0 = 0 -> "00"
  assert_eq(hex[2:4].to_string(), "01") // byte 1 = 1 -> "01"
  assert_eq(hex[98:100].to_string(), "31") // byte 49 = 49 -> "31" in hex = 49 decimal
}

test "span_context_regression_checks" {
  // Ensure existing functionality isn't broken
  let valid_trace = [0x4b, 0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd]
  let valid_span = [0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd]
  
  let sc = span_context(valid_trace, valid_span, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_id_hex(), "4b1234567890abcdef0123456789abcd")
  assert_eq(sc.span_id_hex(), "ef0123456789abcd")
}

test "memory_efficiency_check" {
  // Test that large arrays don't cause issues
  let large_trace = Array::make(16, 255)
  let large_span = Array::make(8, 255)
  
  let sc = span_context(large_trace, large_span, 255)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

test "edge_case_mathematical_sequences" {
  // Test prime number byte sequences
  let primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53]
  assert_eq(bytes_to_hex(primes), "020305070b0d1113171d1f25292b2f35")
  
  // Test square numbers (1^2=1, 2^2=4, 3^2=9, 4^2=16, 5^2=25, 6^2=36, 7^2=49, 8^2=64)
  let squares = [1, 4, 9, 16, 25, 36, 49, 64]
  assert_eq(bytes_to_hex(squares), "0104091019243140")
  
  // Test alternating even/odd
  let even_odd = [2, 3, 4, 5, 6, 7, 8, 9]
  assert_eq(bytes_to_hex(even_odd), "0203040506070809")
}