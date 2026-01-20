// Additional comprehensive tests for SpanContext and W3C Trace Context

// Enhanced SpanContext tests
test "span_context_equality_test" {
  let trace_id1 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id1 = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc1 = span_context(trace_id1, span_id1, 1)
  
  let trace_id2 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id2 = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc2 = span_context(trace_id2, span_id2, 1)
  
  // Same trace and span IDs should create equivalent contexts
  assert_eq(sc1.is_valid(), sc2.is_valid())
  assert_eq(sc1.is_sampled(), sc2.is_sampled())
}

test "span_context_boundary_conditions" {
  // Test minimum valid values
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  
  // Test maximum values
  let trace_id_max = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id_max = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc_max = span_context(trace_id_max, span_id_max, 1)
  assert_true(sc_max.is_valid())
}

test "span_context_invalid_edge_cases" {
  // All zeros (invalid)
  let sc_all_zeros = invalid_span_context()
  assert_false(sc_all_zeros.is_valid())
  
  // Wrong trace_id length
  let wrong_trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc_wrong_length = span_context(wrong_trace_id, span_id, 1)
  assert_false(sc_wrong_length.is_valid())
  
  // Wrong span_id length
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let wrong_span_id = [16, 17, 18, 19, 20, 21, 22]
  let sc_wrong_span = span_context(trace_id, wrong_span_id, 1)
  assert_false(sc_wrong_span.is_valid())
}

// W3C Trace Context parsing tests
test "w3c_trace_context_comprehensive" {
  // Test various hex string formats
  assert_eq(hex_to_int("00"), 0)
  assert_eq(hex_to_int("ff"), 255)
  assert_eq(hex_to_int("dead"), 57005)
  assert_eq(hex_to_int("DEAD"), 57005)
}

test "w3c_hex_to_bytes_comprehensive" {
  // Test various byte sequences
  let bytes1 = hex_to_bytes("00")
  assert_eq(bytes1.length(), 1)
  assert_eq(bytes1[0], 0)
  
  let bytes2 = hex_to_bytes("ff")
  assert_eq(bytes2.length(), 1)
  assert_eq(bytes2[0], 255)
  
  let bytes3 = hex_to_bytes("deadbeef")
  assert_eq(bytes3.length(), 4)
  assert_eq(bytes3[0], 222)
  assert_eq(bytes3[1], 173)
  assert_eq(bytes3[2], 190)
  assert_eq(bytes3[3], 239)
}

test "w3c_edge_cases" {
  // Empty string
  let empty_bytes = hex_to_bytes("")
  assert_eq(empty_bytes.length(), 0)
  
  // Single character (should be ignored)
  let single_char = hex_to_bytes("a")
  assert_eq(single_char.length(), 0)
  
  // Odd length (should process pairs)
  let odd_length = hex_to_bytes("abc")
  assert_eq(odd_length.length(), 1)
  assert_eq(odd_length[0], 171)  // 0xab
}

// Performance tests for string operations
test "string_performance_test" {
  // Test with longer strings
  let long_hex = "0123456789abcdef0123456789abcdef"
  let bytes = hex_to_bytes(long_hex)
  assert_eq(bytes.length(), 16)

  // Test repeated operations
  let mut i = 0
  while i < 100 {
    let result = hex_to_int("dead")
    assert_eq(result, 57005)
    i = i + 1
  }
}

// Integration test combining multiple operations
test "span_context_integration_test" {
  // Create a trace ID from hex
  let trace_hex = "4f1e2d3c1b5a7968"
  let trace_bytes = hex_to_bytes(trace_hex)
  assert_eq(trace_bytes.length(), 8)
  
  // Create a span ID from hex  
  let span_hex = "6f5a4e3d"
  let span_bytes = hex_to_bytes(span_hex)
  assert_eq(span_bytes.length(), 4)
  
  // Create span context
  let sc = span_context(trace_bytes + trace_bytes, span_bytes + span_bytes, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
  
  // Verify hex conversion
  let trace_hex_result = sc.trace_id_hex()
  let expected_trace = "4f1e2d3c1b5a79684f1e2d3c1b5a7968"
  assert_eq(trace_hex_result, expected_trace)
}