// Additional stress and boundary tests for SpanContext
test "span_context_stress_test" {
  // Test with maximum valid values
  let max_trace = []
  let mut i = 0
  while i < 16 {
    max_trace = max_trace + [255]
    i = i + 1
  }
  
  let max_span = []
  let mut j = 0
  while j < 8 {
    max_span = max_span + [255]
    j = j + 1
  }
  
  let sc_max = span_context(max_trace, max_span, 1)
  assert_true(sc_max.is_valid())
  assert_true(sc_max.is_sampled())
}

test "span_context_stress_unsampled" {
  // Test with sampled flag off
  let trace_id = []
  let mut i = 0
  while i < 16 {
    trace_id = trace_id + [i]
    i = i + 1
  }
  
  let span_id = []
  let mut j = 0
  while j < 8 {
    span_id = span_id + [j + 16]
    j = j + 1
  }
  
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

// Hex conversion stress tests
test "hex_conversion_stress_test" {
  // Test large hex numbers
  assert_eq(hex_to_int("ffffffff"), 4294967295)
  assert_eq(hex_to_int("00000000"), 0)
  assert_eq(hex_to_int("12345678"), 305419896)
}

test "hex_to_bytes_stress_test" {
  // Test large byte sequences
  let large_hex = "ff" * 32  // 32 bytes of 0xFF
  let bytes = hex_to_bytes(large_hex)
  assert_eq(bytes.length(), 32)
  
  let mut i = 0
  while i < 32 {
    assert_eq(bytes[i], 255)
    i = i + 1
  }
}

test "edge_case_hex_combinations" {
  // Test various hex combinations
  assert_eq(hex_to_int("a"), 10)
  assert_eq(hex_to_int("F"), 15)
  assert_eq(hex_to_int("10"), 16)
  assert_eq(hex_to_int("100"), 256)
}

// Boundary string tests
test "boundary_string_tests" {
  // Test empty string operations
  let empty = ""
  let empty_bytes = hex_to_bytes(empty)
  assert_eq(empty_bytes.length(), 0)
  
  // Test single character
  let single = "f"
  let single_bytes = hex_to_bytes(single)
  assert_eq(single_bytes.length(), 0)  // Should be ignored as odd length
  
  // Test two characters
  let pair = "ff"
  let pair_bytes = hex_to_bytes(pair)
  assert_eq(pair_bytes.length(), 1)
  assert_eq(pair_bytes[0], 255)
}

// Performance regression test
test "performance_regression_test" {
  let start_time = 0  // Placeholder for timing
  
  // Test many hex operations
  let mut count = 0
  let mut total = 0
  while count < 1000 {
    let result = hex_to_int("deadbeef")
    total = total + result
    count = count + 1
  }
  
  assert_eq(total, 3735928559 * 1000)
}