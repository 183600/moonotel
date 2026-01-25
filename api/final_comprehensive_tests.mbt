// Final comprehensive test suite for OpenTelemetry Tracing SDK

// Advanced SpanContext boundary and edge case tests
test "span_context_max_trace_flags" {
  let tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  
  // Test with maximum trace flag values (only LSB matters for sampling)
  assert_false(span_context(tid, sid, 0).is_sampled())
  assert_true(span_context(tid, sid, 1).is_sampled())
  assert_false(span_context(tid, sid, 2).is_sampled())
  assert_true(span_context(tid, sid, 3).is_sampled())
}

test "span_context_alternating_bit_patterns" {
  let tid = Array::make(16, 0)
  let sid = Array::make(8, 0)
  
  // Test alternating patterns for validity
  let tid_pattern1 = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1]
  let sid_pattern1 = [0, 1, 0, 1, 0, 1, 0, 1]
  
  assert_true(span_context(tid_pattern1, sid_pattern1, 0).is_valid())
}

test "span_context_consecutive_bit_patterns" {
  let tid_consecutive = [1, 3, 7, 15, 31, 63, 127, 255, 1, 3, 7, 15, 31, 63, 127, 255]
  let sid_consecutive = [1, 3, 7, 15, 31, 63, 127, 255]
  
  assert_true(span_context(tid_consecutive, sid_consecutive, 1).is_valid())
}

test "span_context_decreasing_patterns" {
  let tid_decreasing = [255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240]
  let sid_decreasing = [255, 254, 253, 252, 251, 250, 249, 248]
  
  assert_true(span_context(tid_decreasing, sid_decreasing, 1).is_valid())
}

test "hex_encoding_mathematical_sequences" {
  // Simple sequence for testing
  let fibonacci_bytes = [1, 1, 2, 3, 5, 8, 13, 8, 21, 34, 55, 89, 144, 233, 255, 255]
  let hex = bytes_to_hex(fibonacci_bytes)
  assert_eq(hex.length(), 32)
}

test "hex_encoding_prime_numbers" {
  // Use smaller prime numbers to avoid overflow issues
  let primes = [2, 3, 5, 7, 11, 13, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15]
  let hex = bytes_to_hex(primes)
  assert_eq(hex.length(), 32)
}

test "byte_to_hex_boundary_values" {
  assert_eq(byte_to_hex_char(0), "0")
  assert_eq(byte_to_hex_char(15), "f")
  assert_eq(byte_to_hex_char(-1), "0") // Negative input
  assert_eq(byte_to_hex_char(16), "0") // Overflow
  assert_eq(byte_to_hex_char(255), "0") // Large input
}

test "is_zero_mixed_patterns" {
  let mostly_zeros = Array::make(20, 0)
  mostly_zeros[10] = 1
  assert_false(is_zero(mostly_zeros))
  
  let single_nonzero = Array::make(100, 0)
  single_nonzero[99] = 255
  assert_false(is_zero(single_nonzero))
}

test "span_context_sequential_increments" {
  let base_tid = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  let base_sid = [1, 1, 1, 1, 1, 1, 1, 1]
  
  let sc1 = span_context(base_tid, base_sid, 0)
  let sc2 = span_context(base_tid, base_sid, 1)
  
  assert_false(sc1.is_sampled())
  assert_true(sc2.is_sampled())
}

test "bytes_to_hex_empty_array" {
  assert_eq(bytes_to_hex([]), "")
}

test "bytes_to_hex_single_zero" {
  assert_eq(bytes_to_hex([0]), "00")
}

test "span_context_trace_flag_parity" {
  let tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  
  assert_false(span_context(tid, sid, 0).is_sampled())
  assert_true(span_context(tid, sid, 1).is_sampled())
  assert_false(span_context(tid, sid, 2).is_sampled())
  assert_true(span_context(tid, sid, 3).is_sampled())
  assert_false(span_context(tid, sid, 4).is_sampled())
  assert_true(span_context(tid, sid, 5).is_sampled())
  assert_false(span_context(tid, sid, 6).is_sampled())
  assert_true(span_context(tid, sid, 7).is_sampled())
}

test "span_context_large_byte_values" {
  let max_bytes = Array::make(16, 255)
  let max_sid = Array::make(8, 255)
  
  let sc = span_context(max_bytes, max_sid, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

test "hex_encoding_mixed_case_boundary" {
  let boundary_bytes = [0, 1, 14, 15, 10, 11, 12, 13]
  let hex = bytes_to_hex(boundary_bytes)
  assert_eq(hex.length(), 16)
}

test "span_context_invalid_partial_zeros" {
  let tid_mostly_valid = Array::make(16, 1)
  tid_mostly_valid[0] = 0
  
  let sid_valid = Array::make(8, 1)
  
  // This should still be valid since not all trace_id is zero
  assert_true(span_context(tid_mostly_valid, sid_valid, 0).is_valid())
}

test "is_zero_alternating_patterns" {
  let alt_zeros_ones = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1]
  assert_false(is_zero(alt_zeros_ones))
  
  let all_zeros = Array::make(32, 0)
  assert_true(is_zero(all_zeros))
}

test "bytes_to_hex_performance_large_array" {
  let large_array = Array::make(1000, 255)
  let hex = bytes_to_hex(large_array)
  assert_eq(hex.length(), 2000)
}

test "span_context_stress_concurrent_sampled" {
  let tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  
  // Test multiple sampled contexts
  let sc1 = span_context(tid, sid, 1)
  let sc2 = span_context(tid, sid, 3)
  let sc3 = span_context(tid, sid, 255)
  
  assert_true(sc1.is_sampled())
  assert_true(sc2.is_sampled())
  assert_true(sc3.is_sampled())
}

test "byte_to_hex_extreme_values" {
  assert_eq(byte_to_hex_char(0), "0")
  assert_eq(byte_to_hex_char(15), "f")
  assert_eq(byte_to_hex_char(-1), "0") // Negative input returns "0"
  assert_eq(byte_to_hex_char(16), "0") // Overflow returns "0"
  assert_eq(byte_to_hex_char(100), "0") // Large input returns "0"
}

test "span_context_hex_consistency" {
  let tid = [255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0]
  let sid = [255, 0, 255, 0, 255, 0, 255, 0]
  
  let sc = span_context(tid, sid, 1)
  assert_eq(sc.trace_id_hex(), "ff00ff00ff00ff00ff00ff00ff00ff00")
  assert_eq(sc.span_id_hex(), "ff00ff00ff00ff00")
}

test "is_zero_edge_case_single_element" {
  assert_true(is_zero([0]))
  assert_false(is_zero([1]))
  assert_false(is_zero([-1]))
}

test "bytes_to_hex_scientific_notation_pattern" {
  // Simple pattern for testing
  let simple_pattern = [2, 7, 1, 8, 2, 8, 1, 8, 2, 8, 4, 5, 9, 0, 4, 5]
  let hex = bytes_to_hex(simple_pattern)
  assert_eq(hex.length(), 32)
}

test "span_context_minimal_valid" {
  let minimal_tid = Array::make(16, 0)
  minimal_tid[15] = 1
  
  let minimal_sid = Array::make(8, 0)
  minimal_sid[7] = 1
  
  let sc = span_context(minimal_tid, minimal_sid, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "hex_encoding_powers_of_two" {
  let powers_of_two = [1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128]
  let hex = bytes_to_hex(powers_of_two)
  assert_eq(hex, "01020408102040800102040810204080")
}

test "span_context_zero_then_nonzero" {
  let tid_pattern = Array::make(16, 0)
  tid_pattern[15] = 255
  
  let sid_pattern = Array::make(8, 0)
  sid_pattern[7] = 128
  
  let sc = span_context(tid_pattern, sid_pattern, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "bytes_to_hex_string_manipulation_large" {
  let large_repeating = Array::make(50, 170) // 0xAA
  let hex = bytes_to_hex(large_repeating)
  assert_eq(hex.length(), 100)
  assert_true(hex.has_prefix("aaaa"))
  assert_true(hex.has_suffix("aaaa"))
}

test "span_context_overflow_trace_flags" {
  let tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  
  assert_true(span_context(tid, sid, 65535).is_sampled())
  assert_true(span_context(tid, sid, -1).is_sampled())
}

test "is_zero_geometric_progression" {
  let geo_prog = [1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128]
  assert_false(is_zero(geo_prog))
}

test "span_context_alternating_sampling" {
  let tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  
  assert_false(span_context(tid, sid, 0).is_sampled())
  assert_true(span_context(tid, sid, 1).is_sampled())
  assert_false(span_context(tid, sid, 2).is_sampled())
  assert_true(span_context(tid, sid, 3).is_sampled())
}

test "bytes_to_hex_character_encoding_test" {
  let char_codes = [65, 66, 67, 97, 98, 99, 48, 49, 50] // ABCabc012
  let hex = bytes_to_hex(char_codes)
  assert_eq(hex, "414243616263303132")
}

test "span_context_complex_validity_pattern" {
  let complex_tid = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1]
  let complex_sid = [1, 0, 1, 0, 1, 0, 1, 0]
  
  let sc = span_context(complex_tid, complex_sid, 1)
  assert_true(sc.is_valid())
  // This pattern creates alternating bits, so the hex should reflect this
  let trace_hex = sc.trace_id_hex()
  let span_hex = sc.span_id_hex()
  assert_eq(trace_hex.length(), 32)
  assert_eq(span_hex.length(), 16)
}

test "is_zero_stress_test" {
  let large_array = Array::make(10000, 0)
  assert_true(is_zero(large_array))
  
  let modified_array = large_array
  modified_array[9999] = 1
  assert_false(is_zero(modified_array))
}

test "hex_encoding_mathematical_constants" {
  // Simple pi digits approximation within byte range
  let pi_bytes = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3]
  let hex = bytes_to_hex(pi_bytes)
  assert_eq(hex.length(), 32)
}

test "span_context_sequential_bytes" {
  let sequential_tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let sequential_sid = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc = span_context(sequential_tid, sequential_sid, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "0102030405060708090a0b0c0d0e0f10")
  assert_eq(sc.span_id_hex(), "0102030405060708")
}

test "byte_to_hex_stress_boundary" {
  // Test all boundary conditions for byte_to_hex_char
  let mut all_valid = true
  let mut i = 0
  while i < 16 {
    let result = byte_to_hex_char(i)
    let expected = match i {
      0 => "0"
      1 => "1"
      2 => "2"
      3 => "3"
      4 => "4"
      5 => "5"
      6 => "6"
      7 => "7"
      8 => "8"
      9 => "9"
      10 => "a"
      11 => "b"
      12 => "c"
      13 => "d"
      14 => "e"
      15 => "f"
      _ => "0"
    }
    if result != expected {
      all_valid = false
    }
    i = i + 1
  }
  assert_true(all_valid)
}

test "span_context_mixed_validity_edges" {
  let edge_tid = Array::make(16, 0)
  edge_tid[0] = 1
  
  let edge_sid = Array::make(8, 0)
  edge_sid[0] = 1
  
  let sc = span_context(edge_tid, edge_sid, 1)
  assert_true(sc.is_valid())
  let trace_hex = sc.trace_id_hex()
  let span_hex = sc.span_id_hex()
  assert_eq(trace_hex[0:2], "01")
  assert_eq(span_hex[0:2], "01")
}

test "bytes_to_hex_repeated_patterns" {
  let ab_pattern = [10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11]
  let hex = bytes_to_hex(ab_pattern)
  assert_eq(hex, "0a0b0a0b0a0b0a0b0a0b0a0b0a0b0a0b")
}

test "span_context_stress_random_like" {
  let pseudo_random = [42, 17, 89, 23, 67, 91, 34, 78, 12, 56, 98, 33, 77, 19, 84, 29]
  let sid_random = [45, 78, 23, 67, 91, 34, 82, 15]
  
  let sc = span_context(pseudo_random, sid_random, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "is_zero_final_boundary_test" {
  let boundary_array = Array::make(256, 0)
  assert_true(is_zero(boundary_array))
  
  let single_change = boundary_array
  single_change[128] = 1
  assert_false(is_zero(single_change))
}