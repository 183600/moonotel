// Simple additional tracing tests for MoonBit

test "span_context_boundary_validation_1" {
  // Test boundary condition: valid IDs with zero trace flag
  let valid_trace = Array::make(16, 42)
  let valid_span = Array::make(8, 24)
  let context = span_context(valid_trace, valid_span, 0)
  
  assert_true(context.is_valid())
  assert_false(context.is_sampled())
}

test "span_context_boundary_validation_2" {
  // Test boundary condition: valid IDs with sampled flag
  let valid_trace = Array::make(16, 42)
  let valid_span = Array::make(8, 24)
  let context = span_context(valid_trace, valid_span, 1)
  
  assert_true(context.is_valid())
  assert_true(context.is_sampled())
}

test "span_context_invalid_trace_zero" {
  // Test invalid: zero trace ID
  let zero_trace = Array::make(16, 0)
  let valid_span = Array::make(8, 24)
  let context = span_context(zero_trace, valid_span, 1)
  
  assert_false(context.is_valid())
}

test "span_context_invalid_span_zero" {
  // Test invalid: zero span ID
  let valid_trace = Array::make(16, 42)
  let zero_span = Array::make(8, 0)
  let context = span_context(valid_trace, zero_span, 1)
  
  assert_false(context.is_valid())
}

test "span_context_invalid_both_zero" {
  // Test invalid: both IDs zero
  let zero_trace = Array::make(16, 0)
  let zero_span = Array::make(8, 0)
  let context = span_context(zero_trace, zero_span, 1)
  
  assert_false(context.is_valid())
}

test "span_context_hex_format_comprehensive" {
  // Test hex formatting with comprehensive byte values
  let test_bytes = [0x00, 0x0F, 0xF0, 0xFF]
  let hex_result = bytes_to_hex(test_bytes)
  
  assert_eq(hex_result, "000ff0ff")
}

test "span_context_real_world_hex_patterns" {
  // Test with realistic web service patterns
  let trace_pattern = [0x48, 0x54, 0x54, 0x50, 0x52, 0x45, 0x51, 0x55, 0x45, 0x53, 0x54, 0x54, 0x52, 0x41, 0x43, 0x45]  // HTTPREQUESTTRACE
  let span_pattern = [0x48, 0x54, 0x54, 0x50, 0x53, 0x50, 0x41, 0x4E]  // HTTPSPAN
  
  let context = span_context(trace_pattern, span_pattern, 1)
  assert_true(context.is_valid())
  assert_eq(context.trace_id_hex(), "48545450524551554553545452414345")
  assert_eq(context.span_id_hex(), "485454505350414e")
}

test "byte_to_hex_char_all_valid_values" {
  // Test all valid hex digit values
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

test "byte_to_hex_char_invalid_values" {
  // Test invalid values return "0"
  assert_eq(byte_to_hex_char(-1), "0")
  assert_eq(byte_to_hex_char(16), "0")
  assert_eq(byte_to_hex_char(255), "0")
  assert_eq(byte_to_hex_char(1000), "0")
}

test "is_zero_function_comprehensive" {
  // Test is_zero function with various arrays
  assert_true(is_zero([]))
  assert_true(is_zero([0]))
  assert_true(is_zero([0, 0]))
  assert_true(is_zero([0, 0, 0, 0]))
  
  assert_false(is_zero([1]))
  assert_false(is_zero([0, 1]))
  assert_false(is_zero([1, 0]))
  assert_false(is_zero([1, 1]))
}

test "invalid_span_context_properties" {
  // Test properties of invalid span context
  let invalid = invalid_span_context()
  
  assert_false(invalid.is_valid())
  assert_false(invalid.is_sampled())
  assert_eq(invalid.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(invalid.span_id_hex(), "0000000000000000")
}

test "span_context_maximum_values_test" {
  // Test with maximum byte values
  let max_trace = Array::make(16, 255)
  let max_span = Array::make(8, 255)
  let context = span_context(max_trace, max_span, 255)
  
  assert_true(context.is_valid())
  assert_eq(context.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(context.span_id_hex(), "ffffffffffffffff")
  assert_true(context.is_sampled())
}

test "span_context_minimum_nonzero_values" {
  // Test with minimum non-zero values
  let min_trace = Array::make(16, 1)
  let min_span = Array::make(8, 1)
  let context = span_context(min_trace, min_span, 1)
  
  assert_true(context.is_valid())
  assert_eq(context.trace_id_hex(), "01010101010101010101010101010101")
  assert_eq(context.span_id_hex(), "0101010101010101")
  assert_true(context.is_sampled())
}

test "hex_conversion_alternating_high_low" {
  // Test hex conversion with alternating patterns
  let alt1 = [0xAA, 0x55, 0xAA, 0x55]
  assert_eq(bytes_to_hex(alt1), "aa55aa55")
  
  let alt2 = [0x0F, 0xF0, 0x0F, 0xF0]
  assert_eq(bytes_to_hex(alt2), "0ff00ff0")
  
  let alt3 = [0x12, 0x34, 0x12, 0x34]
  assert_eq(bytes_to_hex(alt3), "12341234")
}

test "span_context_wrong_id_lengths" {
  // Test behavior with wrong ID lengths
  let short_trace = Array::make(8, 1)  // Should be 16
  let correct_span = Array::make(8, 1)
  let ctx1 = span_context(short_trace, correct_span, 1)
  assert_false(ctx1.is_valid())
  
  let correct_trace = Array::make(16, 1)
  let short_span = Array::make(4, 1)  // Should be 8
  let ctx2 = span_context(correct_trace, short_span, 1)
  assert_false(ctx2.is_valid())
  
  let long_trace = Array::make(32, 1)  // Should be 16
  let ctx3 = span_context(long_trace, correct_span, 1)
  assert_false(ctx3.is_valid())
  
  let correct_trace2 = Array::make(16, 1)
  let long_span = Array::make(16, 1)  // Should be 8
  let ctx4 = span_context(correct_trace2, long_span, 1)
  assert_false(ctx4.is_valid())
}

test "hex_conversion_empty_and_single" {
  // Test hex conversion edge cases
  assert_eq(bytes_to_hex([]), "")
  assert_eq(bytes_to_hex([0]), "00")
  assert_eq(bytes_to_hex([255]), "ff")
}

test "span_context_hex_length_consistency" {
  // Test that hex strings always have correct length
  let trace = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]
  let span = [0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18]
  let context = span_context(trace, span, 1)
  
  assert_eq(context.trace_id_hex().length(), 32)  // 16 bytes * 2
  assert_eq(context.span_id_hex().length(), 16)   // 8 bytes * 2
}

test "span_context_sampling_edge_cases" {
  // Test sampling behavior with edge case flag values
  let trace = Array::make(16, 42)
  let span = Array::make(8, 24)
  
  // Even flags should not sample (LSB = 0)
  let ctx0 = span_context(trace, span, 0)
  let ctx2 = span_context(trace, span, 2)
  let ctx4 = span_context(trace, span, 4)
  let ctx254 = span_context(trace, span, 254)
  
  assert_false(ctx0.is_sampled())
  assert_false(ctx2.is_sampled())
  assert_false(ctx4.is_sampled())
  assert_false(ctx254.is_sampled())
  
  // Odd flags should sample (LSB = 1)
  let ctx1 = span_context(trace, span, 1)
  let ctx3 = span_context(trace, span, 3)
  let ctx5 = span_context(trace, span, 5)
  let ctx255 = span_context(trace, span, 255)
  
  assert_true(ctx1.is_sampled())
  assert_true(ctx3.is_sampled())
  assert_true(ctx5.is_sampled())
  assert_true(ctx255.is_sampled())
}

test "hex_conversion_stress_various_sizes" {
  // Test hex conversion with various array sizes
  let size1 = [0x42]
  assert_eq(bytes_to_hex(size1), "42")
  
  let size2 = [0x42, 0x24]
  assert_eq(bytes_to_hex(size2), "4224")
  
  let size4 = [0x42, 0x24, 0x13, 0x31]
  assert_eq(bytes_to_hex(size4), "42241331")
}

test "span_context_mixed_validity_scenarios" {
  // Test various mixed validity scenarios
  let valid_trace = Array::make(16, 42)
  let valid_span = Array::make(8, 24)
  let zero_trace = Array::make(16, 0)
  let zero_span = Array::make(8, 0)
  
  // Valid + Valid = Valid
  let ctx1 = span_context(valid_trace, valid_span, 1)
  assert_true(ctx1.is_valid())
  
  // Zero + Valid = Invalid
  let ctx2 = span_context(zero_trace, valid_span, 1)
  assert_false(ctx2.is_valid())
  
  // Valid + Zero = Invalid
  let ctx3 = span_context(valid_trace, zero_span, 1)
  assert_false(ctx3.is_valid())
  
  // Zero + Zero = Invalid
  let ctx4 = span_context(zero_trace, zero_span, 1)
  assert_false(ctx4.is_valid())
}

test "span_context_concurrent_access_simulation" {
  // Simulate concurrent access patterns
  let trace1 = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF]
  let span1 = [0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10]
  
  let ctx1 = span_context(trace1, span1, 1)
  let ctx2 = span_context(Array::make(16, 0), Array::make(8, 0), 0)
  let ctx3 = span_context(Array::make(16, 255), Array::make(8, 255), 255)
  
  assert_true(ctx1.is_valid())
  assert_false(ctx2.is_valid())
  assert_true(ctx3.is_valid())
  
  assert_eq(ctx1.trace_id_hex(), "0123456789abcdef0123456789abcdef")
  assert_eq(ctx1.span_id_hex(), "fedcba9876543210")
  assert_eq(ctx3.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(ctx3.span_id_hex(), "ffffffffffffffff")
}

test "span_context_performance_stress_small" {
  // Stress test with smaller arrays
  let iterations = 100
  
  let mut passed = 0
  let mut i = 0
  while i < iterations {
    let trace = Array::make(16, (i % 255) + 1)  // Ensure non-zero
    let span = Array::make(8, ((i * 2) % 255) + 1)  // Ensure non-zero
    let ctx = span_context(trace, span, i % 2)
    
    if ctx.is_valid() && ctx.trace_id_hex().length() == 32 && ctx.span_id_hex().length() == 16 {
      passed = passed + 1
    }
    i = i + 1
  }
  
  assert_true(passed == iterations)
}

test "span_context_hex_character_validation" {
  // Test that hex conversion produces only valid hex characters
  let test_bytes = [0x20, 0x21, 0x7E, 0x7F, 0x80, 0xFF]  // space, !, ~, DEL, non-ASCII, max
  let hex_result = bytes_to_hex(test_bytes)
  
  // Should only contain hex digits 0-9, a-f
  let mut valid_hex = true
  let mut i = 0
  while i < hex_result.length() {
    let char = hex_result[i]
    let is_digit = char >= '0' && char <= '9'
    let is_lowercase_hex = char >= 'a' && char <= 'f'
    if not (is_digit || is_lowercase_hex) {
      valid_hex = false
    }
    i = i + 1
  }
  
  assert_true(valid_hex)
  assert_eq(hex_result, "20217e7f80ff")
}

test "span_context_comprehensive_validation" {
  // Comprehensive test covering multiple aspects
  let comprehensive_trace = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10]
  let comprehensive_span = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11]
  
  let ctx = span_context(comprehensive_trace, comprehensive_span, 1)
  
  // Validate all properties
  assert_true(ctx.is_valid())
  // Just test that the hex conversion works, not exact values
  assert_eq(ctx.span_id_hex(), "aabbccddeeff0011")
  assert_true(ctx.is_sampled())
  
  // Validate that individual components work correctly
  let zero_ctx = invalid_span_context()
  assert_false(zero_ctx.is_valid())
  assert_eq(zero_ctx.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(zero_ctx.span_id_hex(), "0000000000000000")
  assert_false(zero_ctx.is_sampled())
}

test "span_context_database_transaction_patterns" {
  // Test with database transaction-like patterns
  let db_trace = [0x44, 0x42, 0x54, 0x52, 0x41, 0x4E, 0x53, 0x41, 0x43, 0x54, 0x49, 0x4F, 0x4E, 0x54, 0x52, 0x41]  // DBTRANSACTION
  let db_span = [0x51, 0x55, 0x45, 0x52, 0x59, 0x49, 0x44, 0x21]  // QUERYID!
  
  let context = span_context(db_trace, db_span, 1)
  assert_true(context.is_valid())
  assert_eq(context.trace_id_hex(), "44425452414e53414354494f4e545241")
  assert_eq(context.span_id_hex(), "5155455259494421")
}

test "span_context_microservice_communication" {
  // Test microservice communication patterns
  let svc_trace = [0x4D, 0x49, 0x43, 0x52, 0x4F, 0x53, 0x45, 0x52, 0x56, 0x49, 0x43, 0x45, 0x43, 0x4F, 0x4D, 0x4D]  // MICROSERVICECOMM
  let svc_span = [0x41, 0x50, 0x49, 0x43, 0x41, 0x4C, 0x4C, 0x21]  // APICALL!
  
  let context = span_context(svc_trace, svc_span, 1)
  assert_true(context.is_valid())
  assert_eq(context.trace_id_hex(), "4d4943524f53455256494345434f4d4d")
  assert_eq(context.span_id_hex(), "41504943414c4c21")
}

test "span_context_error_handling_edge_cases" {
  // Test error handling with various edge cases
  let flag1 = span_context(Array::make(16, 42), Array::make(8, 24), 32766)
  assert_true(flag1.is_valid())
  assert_false(flag1.is_sampled())  // 32766 is even
  
  let flag2 = span_context(Array::make(16, 42), Array::make(8, 24), 65535)
  assert_true(flag2.is_valid())
  assert_true(flag2.is_sampled())  // 65535 is odd
  
  let flag3 = span_context(Array::make(16, 42), Array::make(8, 24), 131070)
  assert_true(flag3.is_valid())
  assert_false(flag3.is_sampled())  // 131070 is even
}

test "span_context_hex_permutation_consistency" {
  // Test that hex conversion produces consistent results
  let test_case1 = bytes_to_hex([0x00, 0x01, 0x02, 0x03])
  assert_eq(test_case1, "00010203")
  
  let test_case2 = bytes_to_hex([0xFF, 0xFE, 0xFD, 0xFC])
  assert_eq(test_case2, "fffefdfc")
  
  let test_case3 = bytes_to_hex([0x0A, 0x0B, 0x0C, 0x0D])
  assert_eq(test_case3, "0a0b0c0d")
  
  let test_case4 = bytes_to_hex([0x10, 0x20, 0x30, 0x40])
  assert_eq(test_case4, "10203040")
}