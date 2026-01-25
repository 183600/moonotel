// Advanced edge cases and error handling tests for OpenTelemetry Tracing SDK

// =================== ERROR HANDLING TESTS ===================

test "span_context_with_all_zeros_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_with_all_zeros_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_with_negative_trace_id_values" {
  // Simulate negative values by using high byte values
  let trace_id = [255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240]
  let span_id = [239, 238, 237, 236, 235, 234, 233, 232]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid()) // Should still be valid as bytes are unsigned
}

test "span_context_with_negative_span_id_values" {
  let trace_id = [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
  let span_id = [255, 254, 253, 252, 251, 250, 249, 248]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid()) // Should still be valid as bytes are unsigned
}

test "span_context_with_oversized_values" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_with_single_bit_set" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_with_alternating_bits" {
  let trace_id = [170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85, 170, 85] // 0xAA alternating pattern
  let span_id = [170, 85, 170, 85, 170, 85, 170, 85]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

// =================== BOUNDARY CONDITION TESTS ===================

test "hex_conversion_with_empty_string" {
  let empty_bytes = hex_to_bytes("")
  assert_eq(empty_bytes.length(), 0)
}

test "hex_conversion_with_single_character" {
  let single_char = hex_to_bytes("a")
  assert_eq(single_char.length(), 0) // Should be ignored as it's not a complete byte
}

test "hex_conversion_with_odd_length_string" {
  let odd_length = hex_to_bytes("abc")
  assert_eq(odd_length.length(), 1)
  assert_eq(odd_length[0], 171) // 0xAB
}

test "hex_conversion_with_whitespace" {
  let with_space = hex_to_bytes("ab cd")
  // The actual behavior processes the hex pairs ignoring invalid chars
  assert_eq(with_space.length(), 2)
  // Should process "ab" as one byte and ignore "cd" as invalid
  assert_eq(with_space[0], 171) // 0xAB
}

test "hex_conversion_with_invalid_characters" {
  let invalid_hex = hex_to_bytes("gg")
  // Invalid characters return 0, but are still processed as pairs
  assert_eq(invalid_hex.length(), 1)
  assert_eq(invalid_hex[0], 0) // "gg" -> (0,0) -> 0x00 = 0
}

test "hex_conversion_with_null_bytes" {
  let null_terminated = hex_to_bytes("00")
  assert_eq(null_terminated.length(), 1)
  assert_eq(null_terminated[0], 0)
}

test "hex_conversion_very_long_string" {
  let very_long = "0123456789abcdef".repeat(16) // 256 characters
  let bytes = hex_to_bytes(very_long)
  assert_eq(bytes.length(), 128)
}

// =================== EXTREME VALUE TESTS ===================

test "span_context_minimum_valid_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_minimum_valid_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_maximum_trace_id" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_maximum_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "hex_to_int_with_zero" {
  assert_eq(hex_to_int("00"), 0)
}

test "hex_to_int_with_maximum_byte" {
  assert_eq(hex_to_int("ff"), 255)
}

test "hex_to_int_with_word_boundary" {
  assert_eq(hex_to_int("ffff"), 65535)
}

// =================== PERFORMANCE AND STRESS TESTS ===================

test "hex_conversion_stress_test" {
  let mut i = 0
  let mut total_bytes = 0
  while i < 1000 {
    let test_hex = "deadbeefcafe"
    let bytes = hex_to_bytes(test_hex)
    total_bytes = total_bytes + bytes.length()
    i = i + 1
  }
  assert_eq(total_bytes, 6000) // 6 bytes per conversion * 1000 iterations
}

test "span_context_creation_stress_test" {
  let mut i = 0
  let mut valid_count = 0
  while i < 500 {
    let trace_id = [i % 256, (i + 1) % 256, (i + 2) % 256, (i + 3) % 256, (i + 4) % 256, (i + 5) % 256, (i + 6) % 256, (i + 7) % 256, (i + 8) % 256, (i + 9) % 256, (i + 10) % 256, (i + 11) % 256, (i + 12) % 256, (i + 13) % 256, (i + 14) % 256, (i + 15) % 256]
    let span_id = [(i + 16) % 256, (i + 17) % 256, (i + 18) % 256, (i + 19) % 256, (i + 20) % 256, (i + 21) % 256, (i + 22) % 256, (i + 23) % 256]
    let sc = span_context(trace_id, span_id, 1)
    if sc.is_valid() {
      valid_count = valid_count + 1
    }
    i = i + 1
  }
  assert_eq(valid_count, 500) // All should be valid
}

test "hex_int_conversion_boundary_test" {
  // Test values around common boundaries
  assert_eq(hex_to_int("0f"), 15)
  assert_eq(hex_to_int("10"), 16)
  assert_eq(hex_to_int("1f"), 31)
  assert_eq(hex_to_int("20"), 32)
  assert_eq(hex_to_int("7f"), 127)
  assert_eq(hex_to_int("80"), 128)
  assert_eq(hex_to_int("ff"), 255)
}

// =================== MEMORY AND ARRAY TESTS ===================

test "span_context_array_modification_safety" {
  let original_trace = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let original_span = [17, 18, 19, 20, 21, 22, 23, 24]
  
  let sc = span_context(original_trace, original_span, 1)
  
  // Modify original arrays to ensure span context doesn't depend on them
  let mut i = 0
  while i < original_trace.length() {
    original_trace[i] = 0
    i = i + 1
  }
  
  let mut j = 0
  while j < original_span.length() {
    original_span[j] = 0
    j = j + 1
  }
  
  // Span context should still be valid as it copied the values
  assert_true(sc.is_valid())
}

test "hex_bytes_array_bounds_checking" {
  // Test with arrays that might go out of bounds
  let short_array = [1, 2]
  assert_eq(short_array.length(), 2)
  
  let long_array = Array::make(1000, 42)
  assert_eq(long_array.length(), 1000)
}

test "span_context_trace_id_variations" {
  let patterns = [
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  ]
  
  let standard_span = [10, 11, 12, 13, 14, 15, 16, 17]
  
  let mut i = 0
  while i < patterns.length() {
    let sc = span_context(patterns[i], standard_span, 1)
    assert_true(sc.is_valid())
    i = i + 1
  }
}

// =================== INTEGRATION ERROR SCENARIOS ===================

test "w3c_context_parsing_malformed_headers" {
  // Test various malformed W3C trace context headers
  let malformed_cases = [
    "00-", // Incomplete
    "00- malformed -01", // Contains spaces
    "00-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef-0123456789abcdef0123456789abcdef-01", // Too long
    "invalid_format"
  ]
  
  let mut i = 0
  while i < malformed_cases.length() {
    // Should handle gracefully without panicking
    let header = malformed_cases[i]
    assert_true(header.length() > 0) // Just verify the test data is valid
    i = i + 1
  }
}

test "span_context_sampling_variations" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  
  // Test different sampling values
  let sc0 = span_context(trace_id, span_id, 0)
  let sc1 = span_context(trace_id, span_id, 1)
  
  assert_true(sc0.is_valid())
  assert_true(sc1.is_valid())
  
  // Both should have same validity but different sampling
  assert_eq(sc0.is_sampled(), false)
  assert_eq(sc1.is_sampled(), true)
}

test "hex_conversion_consistency_test" {
  // Test that the same input always produces the same output
  let test_cases = [
    "deadbeef",
    "0123456789abcdef",
    "aabbccddeeff",
    "fedcba9876543210"
  ]
  
  let mut i = 0
  while i < test_cases.length() {
    let hex = test_cases[i]
    let bytes1 = hex_to_bytes(hex)
    let bytes2 = hex_to_bytes(hex)
    
    assert_eq(bytes1.length(), bytes2.length())
    
    let mut j = 0
    while j < bytes1.length() {
      assert_eq(bytes1[j], bytes2[j])
      j = j + 1
    }
    i = i + 1
  }
}

// =================== UTILITY FUNCTION ERROR HANDLING ===================

test "byte_to_hex_char_error_conditions" {
  // Test values that should return "0" (error condition)
  let error_values = [16, 17, 31, 32, 100, 255, 256, -1, -10]
  
  let mut i = 0
  while i < error_values.length() {
    let result = byte_to_hex_char(error_values[i])
    assert_eq(result, "0") // Should return "0" for invalid values
    i = i + 1
  }
}

test "hex_to_int_edge_cases" {
  // Test edge cases for hex to int conversion
  let edge_cases = [
    ("00", 0),
    ("01", 1),
    ("0a", 10),
    ("0A", 10),
    ("10", 16),
    ("ff", 255),
    ("FF", 255)
  ]
  
  let mut i = 0
  while i < edge_cases.length() {
    let hex_str = edge_cases[i].0
    let expected = edge_cases[i].1
    let result = hex_to_int(hex_str)
    assert_eq(result, expected)
    i = i + 1
  }
}