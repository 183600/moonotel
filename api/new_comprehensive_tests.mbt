// New comprehensive tests for enhanced coverage

test "span_context_flags_boundary_values" {
  let tid = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  let sid = [1,2,3,4,5,6,7,8]
  
  // Test minimum valid flags
  let sc0 = span_context(tid, sid, 0)
  assert_false(sc0.is_sampled())
  assert_eq(sc0.trace_flags, 0)
  
  // Test maximum valid flags (within byte range)
  let sc255 = span_context(tid, sid, 255)
  assert_true(sc255.is_sampled())
  assert_eq(sc255.trace_flags, 255)
  
  // Test power of 2 values
  let sc1 = span_context(tid, sid, 1)
  assert_true(sc1.is_sampled())
  
  let sc2 = span_context(tid, sid, 2)
  assert_false(sc2.is_sampled())
  
  let sc4 = span_context(tid, sid, 4)
  assert_false(sc4.is_sampled())
  
  let sc8 = span_context(tid, sid, 8)
  assert_false(sc8.is_sampled())
  
  let sc16 = span_context(tid, sid, 16)
  assert_false(sc16.is_sampled())
  
  let sc32 = span_context(tid, sid, 32)
  assert_false(sc32.is_sampled())
  
  let sc64 = span_context(tid, sid, 64)
  assert_false(sc64.is_sampled())
  
  let sc128 = span_context(tid, sid, 128)
  assert_false(sc128.is_sampled())
}

test "span_context_zero_validation_patterns" {
  let valid_tid = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  let valid_sid = [1,2,3,4,5,6,7,8]
  
  // Test all combinations of zero/non-zero IDs
  assert_true(span_context(valid_tid, valid_sid, 1).is_valid())
  assert_false(span_context(Array::make(16, 0), valid_sid, 1).is_valid())
  assert_false(span_context(valid_tid, Array::make(8, 0), 1).is_valid())
  assert_false(span_context(Array::make(16, 0), Array::make(8, 0), 1).is_valid())
}

test "byte_to_hex_performance_patterns" {
  // Test common byte values in tracing
  let common_bytes = [0x00, 0x01, 0x0A, 0x0F, 0x10, 0x20, 0x3F, 0x40, 0x7F, 0x80, 0xFF]
  let expected = ["00", "01", "0a", "0f", "10", "20", "3f", "40", "7f", "80", "ff"]
  
  let mut i = 0
  while i < common_bytes.length() {
    assert_eq(bytes_to_hex([common_bytes[i]]), expected[i])
    i = i + 1
  }
}

test "hex_encoding_edge_cases" {
  // Test maximum and minimum byte values
  assert_eq(bytes_to_hex([0]), "00")
  assert_eq(bytes_to_hex([255]), "ff")
  
  // Test alternating patterns
  let mut pattern = []
  let mut i = 0
  while i < 16 {
    if i % 2 == 0 {
      pattern = pattern + [0xAA]
    } else {
      pattern = pattern + [0x55]
    }
    i = i + 1
  }
  assert_eq(bytes_to_hex(pattern), "aa55aa55aa55aa55aa55aa55aa55aa55")
}

test "span_context_large_flag_values" {
  let tid = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  let sid = [1,2,3,4,5,6,7,8]
  
  // Test very large flag values
  let sc1024 = span_context(tid, sid, 1024)
  assert_false(sc1024.is_sampled())
  assert_eq(sc1024.trace_flags, 1024)
  
  let sc65535 = span_context(tid, sid, 65535)
  assert_true(sc65535.is_sampled())
  assert_eq(sc65535.trace_flags, 65535)
  
  // Test negative flags (if supported)
  let sc_neg = span_context(tid, sid, -1)
  assert_true(sc_neg.is_sampled()) // -1 & 1 = 1
  assert_eq(sc_neg.trace_flags, -1)
}

test "is_zero_optimization_patterns" {
  // Test various array sizes that might trigger optimizations
  let sizes = [0, 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]
  
  let mut i = 0
  while i < sizes.length() {
    assert_true(is_zero(Array::make(sizes[i], 0)))
    i = i + 1
  }
  
  // Test single non-zero element in large arrays
  let mut j = 0
  while j < sizes.length() {
    if sizes[j] > 0 {
      let arr = Array::make(sizes[j], 0)
      arr[0] = 1
      assert_false(is_zero(arr))
    }
    j = j + 1
  }
}

test "span_context_concurrent_patterns" {
  // Simulate concurrent creation of span contexts
  let mut contexts = []
  let mut i = 0
  while i < 100 {
    let tid = Array::make(16, (i % 256))
    let sid = Array::make(8, (i % 256))
    let flags = i % 2
    let sc = span_context(tid, sid, flags)
    contexts = contexts + [sc]
    i = i + 1
  }
  
  // Verify all contexts were created correctly
  let mut j = 0
  while j < contexts.length() {
    let expected_sampled = (j % 2) != 0
    assert_eq(contexts[j].is_sampled(), expected_sampled)
    j = j + 1
  }
}

test "hex_string_consistency" {
  // Test that hex strings are consistent across different byte orders
  let test_bytes = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF]
  let hex = bytes_to_hex(test_bytes)
  
  // Verify length is exactly 2x the byte count
  assert_eq(hex.length(), 16)
  
  // Verify all characters are valid hex digits
  let mut i = 0
  while i < hex.length() {
    let c = hex[i]
    assert_true((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))
    i = i + 1
  }
}

test "span_context_memory_efficiency" {
  // Test that identical data creates equivalent contexts
  let tid1 = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  let sid1 = [1,2,3,4,5,6,7,8]
  
  let tid2 = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  let sid2 = [1,2,3,4,5,6,7,8]
  
  let sc1 = span_context(tid1, sid1, 1)
  let sc2 = span_context(tid2, sid2, 1)
  
  assert_eq(sc1.trace_id, sc2.trace_id)
  assert_eq(sc1.span_id, sc2.span_id)
  assert_eq(sc1.trace_flags, sc2.trace_flags)
  assert_eq(sc1.is_valid(), sc2.is_valid())
  assert_eq(sc1.is_sampled(), sc2.is_sampled())
}

test "boundary_value_hex_encoding" {
  // Test hex encoding at byte boundaries
  let boundary_values = [0x0, 0xF, 0x10, 0xFF, 0x100, 0xFFF]
  
  let mut i = 0
  while i < boundary_values.length() {
    if boundary_values[i] <= 255 {
      let hex = bytes_to_hex([boundary_values[i]])
      assert_eq(hex.length(), 2)
    }
    i = i + 1
  }
}

test "span_context_extreme_flag_combinations" {
  let tid = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  let sid = [1,2,3,4,5,6,7,8]
  
  // Test all bits set in various positions
  let flag_combinations = [
    0x80000000, // Highest bit set
    0x40000000,
    0x20000000,
    0x10000000,
    0x08000000,
    0x04000000,
    0x02000000,
    0x01000000,
    0x00800000,
    0x00400000,
    0x00200000,
    0x00100000,
    0x00080000,
    0x00040000,
    0x00020000,
    0x00010000,
    0x00008000,
    0x00004000,
    0x00002000,
    0x00001000,
    0x00000800,
    0x00000400,
    0x00000200,
    0x00000100,
    0x00000080,
    0x00000040,
    0x00000020,
    0x00000010,
    0x00000008,
    0x00000004,
    0x00000002,
    0x00000001
  ]
  
  let mut i = 0
  while i < flag_combinations.length() {
    let sc = span_context(tid, sid, flag_combinations[i])
    assert_eq(sc.trace_flags, flag_combinations[i])
    
    // Only odd values (LSB set) should be sampled
    if (flag_combinations[i] & 1) != 0 {
      assert_true(sc.is_sampled())
    } else {
      assert_false(sc.is_sampled())
    }
    i = i + 1
  }
}

test "is_zero_empty_array" {
  // Test edge case of empty array
  let empty = Array::make(0, 0)
  assert_true(is_zero(empty))
  
  // Test empty array vs non-empty with same content
  let single_zero = [0]
  let array_zero = Array::make(1, 0)
  
  assert_true(is_zero(single_zero))
  assert_true(is_zero(array_zero))
}

test "span_context_hex_format_consistency" {
  // Test that hex format is consistent regardless of byte values
  let test_cases = [
    ([0x00], "00"),
    ([0x0F], "0f"),
    ([0xF0], "f0"),
    ([0xFF], "ff"),
    ([0x01, 0x23, 0x45, 0x67], "01234567")
  ]
  
  let mut i = 0
  while i < test_cases.length() {
    let (bytes, expected) = test_cases[i]
    assert_eq(bytes_to_hex(bytes), expected)
    i = i + 1
  }
}

test "byte_to_hex_overflow_protection" {
  // Test that byte_to_hex handles overflow values gracefully
  let overflow_values = [
    -2147483648, // INT_MIN
    -32768,      // INT16_MIN
    -129,        // Just below -128
    -128,        // INT8_MIN
    -1,          // Just below 0
    256,         // Just above 255
    257,         // Above byte range
    32767,       // INT16_MAX
    2147483647   // INT_MAX
  ]
  
  let mut i = 0
  while i < overflow_values.length() {
    let result = byte_to_hex_char(overflow_values[i])
    // Should return "0" for out-of-bounds values
    assert_eq(result, "0")
    i = i + 1
  }
}

test "span_context_large_array_handling" {
  // Test handling of larger arrays to ensure no buffer overflow
  let large_tid = Array::make(256, 1)
  let large_sid = Array::make(128, 1)
  
  let sc = span_context(large_tid, large_sid, 1)
  assert_false(sc.is_valid()) // Wrong length should make it invalid
  
  // Correct lengths but larger values
  let big_tid = [0, 16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 192, 208, 224, 240]
  let big_sid = [0, 32, 64, 96, 128, 160, 192, 224]
  
  let sc_big = span_context(big_tid, big_sid, 1)
  assert_true(sc_big.is_valid())
}

test "hex_encoding_performance_chars" {
  // Test hex encoding for characters that commonly appear in tracing
  let tracing_chars = [
    0x20, // Space
    0x2D, // Dash (-)
    0x5F, // Underscore (_)
    0x61, // 'a'
    0x62, // 'b'
    0x63, // 'c'
    0x64, // 'd'
    0x65, // 'e'
    0x66, // 'f'
    0x30, // '0'
    0x31, // '1'
    0x32, // '2'
    0x33, // '3'
    0x34, // '4'
    0x35, // '5'
    0x36, // '6'
    0x37, // '7'
    0x38, // '8'
    0x39  // '9'
  ]
  
  let expected_hex = [
    "20", "2d", "5f", "61", "62", "63", "64", "65", "66",
    "30", "31", "32", "33", "34", "35", "36", "37", "38", "39"
  ]
  
  let mut i = 0
  while i < tracing_chars.length() {
    let hex = bytes_to_hex([tracing_chars[i]])
    assert_eq(hex, expected_hex[i])
    i = i + 1
  }
}

test "span_context_consecutive_creation" {
  // Test creating many span contexts in sequence
  let mut contexts = []
  let mut i = 0
  while i < 1000 {
    let tid = [(i + 0) % 256, (i + 1) % 256, (i + 2) % 256, (i + 3) % 256, (i + 4) % 256, (i + 5) % 256, (i + 6) % 256, (i + 7) % 256, (i + 8) % 256, (i + 9) % 256, (i + 10) % 256, (i + 11) % 256, (i + 12) % 256, (i + 13) % 256, (i + 14) % 256, (i + 15) % 256]
    let sid = [(i + 0) % 256, (i + 1) % 256, (i + 2) % 256, (i + 3) % 256, (i + 4) % 256, (i + 5) % 256, (i + 6) % 256, (i + 7) % 256]
    
    let flags = i % 256
    let sc = span_context(tid, sid, flags)
    contexts = contexts + [sc]
    i = i + 1
  }
  
  // Verify first and last contexts
  assert_eq(contexts[0].trace_flags, 0)
  assert_false(contexts[0].is_sampled())
  
  assert_eq(contexts[999].trace_flags, 231) // 999 % 256 = 231
  assert_true(contexts[999].is_sampled()) // 231 is odd
}

test "is_zero_single_element_arrays" {
  // Test is_zero with various single-element arrays
  let values = [-128, -1, 0, 1, 127, 255]
  
  let mut i = 0
  while i < values.length() {
    let zero_arr = Array::make(1, 0)
    let non_zero_arr = Array::make(1, values[i])
    
    assert_true(is_zero(zero_arr))
    
    if values[i] == 0 {
      assert_true(is_zero(non_zero_arr))
    } else {
      assert_false(is_zero(non_zero_arr))
    }
    i = i + 1
  }
}

test "span_context_alternating_patterns" {
  // Test span contexts with alternating byte patterns
  let patterns = [
    [0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA],
    [0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55],
    [0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00],
    [0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0]
  ]
  
  let span_patterns = [
    [0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA],
    [0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55],
    [0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00],
    [0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0]
  ]
  
  let mut i = 0
  while i < patterns.length() {
    let sc = span_context(patterns[i], span_patterns[i], i % 2)
    assert_true(sc.is_valid())
    
    let hex_id = sc.trace_id_hex()
    let hex_span = sc.span_id_hex()
    
    // Verify hex strings contain expected patterns
    let _ = hex_span // Suppress unused warning
    let mut j = 0
    while j < 8 {
      assert_true(hex_id.has_prefix(bytes_to_hex([patterns[i][0]]).to_string()))
      j = j + 1
    }
    
    i = i + 1
  }
}

test "byte_to_hex_special_characters" {
  // Test byte_to_hex with special ASCII values
  let special_bytes = [
    9,   // Tab
    10,  // Line feed
    13,  // Carriage return
    32,  // Space
    127, // DEL
    128, // First extended ASCII
    255  // Last byte value
  ]
  
  let expected = ["09", "0a", "0d", "20", "7f", "80", "ff"]
  
  let mut i = 0
  while i < special_bytes.length() {
    let hex = bytes_to_hex([special_bytes[i]])
    assert_eq(hex, expected[i])
    i = i + 1
  }
}

test "span_context_minimal_valid_values" {
  // Test the minimal valid values for a span context
  let min_tid = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1] // Last byte non-zero
  let min_sid = [0, 0, 0, 0, 0, 0, 0, 1] // Last byte non-zero
  
  let sc = span_context(min_tid, min_sid, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000001")
  assert_eq(sc.span_id_hex(), "0000000000000001")
  assert_true(sc.is_sampled())
}

test "span_context_maximal_values" {
  // Test with maximal byte values
  let max_tid = Array::make(16, 255)
  let max_sid = Array::make(8, 255)
  
  let sc = span_context(max_tid, max_sid, 255)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
  assert_true(sc.is_sampled())
}

test "is_zero_progressive_arrays" {
  // Test is_zero with progressively larger arrays
  let sizes = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233] // Fibonacci sequence
  
  let mut i = 0
  while i < sizes.length() {
    let arr = Array::make(sizes[i], 0)
    assert_true(is_zero(arr))
    i = i + 1
  }
  
  // Test same sizes but with one non-zero element
  let mut j = 0
  while j < sizes.length() {
    let arr = Array::make(sizes[j], 0)
    arr[0] = 1
    assert_false(is_zero(arr))
    j = j + 1
  }
}

test "span_context_comprehensive_edge_case_matrix" {
  // Comprehensive edge case testing matrix
  let edge_cases = [
    // (trace_id, span_id, flags, expected_valid, expected_sampled)
    ([0], Array::make(8, 1), 1, false, true),      // Too short trace_id
    (Array::make(16, 0), [1], 1, false, true),      // Too short span_id
    (Array::make(16, 1), Array::make(8, 0), 1, false, true), // Zero span_id
    (Array::make(16, 0), Array::make(8, 1), 1, false, true), // Zero trace_id
    (Array::make(16, 1), Array::make(8, 1), 1, true, true),  // Valid minimal
    (Array::make(16, 255), Array::make(8, 255), 0, true, false), // Valid maximal not sampled
    (Array::make(16, 255), Array::make(8, 255), 255, true, true), // Valid maximal sampled
  ]
  
  let mut i = 0
  while i < edge_cases.length() {
    let (tid, sid, flags, expected_valid, expected_sampled) = edge_cases[i]
    
    // Pad trace_id and span_id to correct lengths
    let padded_tid = tid + Array::make(16 - tid.length(), 0)
    let padded_sid = sid + Array::make(8 - sid.length(), 0)
    
    let sc = span_context(padded_tid, padded_sid, flags)
    assert_eq(sc.is_valid(), expected_valid)
    assert_eq(sc.is_sampled(), expected_sampled)
    
    i = i + 1
  }
}

test "is_zero_optimization_detection" {
  // Test that is_zero works correctly regardless of optimization opportunities
  let patterns = [
    [], // Empty array
    [0], // Single zero
    [0, 0], // Two zeros
    [0, 0, 0], // Three zeros
    [0, 0, 0, 0], // Four zeros (word boundary)
    [0, 0, 0, 0, 0, 0, 0, 0], // Eight zeros (double word)
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], // Sixteen zeros (trace ID size)
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], // Thirty-two zeros
  ]
  
  let mut i = 0
  while i < patterns.length() {
    assert_true(is_zero(patterns[i]))
    i = i + 1
  }
  
  // Test that non-zero patterns are detected correctly
  let non_zero_patterns = [
    [1], // Single non-zero
    [0, 1], // Non-zero at end
    [1, 0], // Non-zero at start
    [0, 0, 1], // Non-zero in middle
    [1, 0, 0, 0, 0, 0, 0, 0], // Non-zero at start of large array
    [0, 0, 0, 0, 0, 0, 0, 1], // Non-zero at end of large array
  ]
  
  let mut j = 0
  while j < non_zero_patterns.length() {
    assert_false(is_zero(non_zero_patterns[j]))
    j = j + 1
  }
}

test "span_context_final_validation_comprehensive" {
  // Final comprehensive validation test
  let test_vectors = [
    // Standard test cases
    ([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16], [1,2,3,4,5,6,7,8], 0, true, false),
    ([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16], [1,2,3,4,5,6,7,8], 1, true, true),
    ([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16], [1,2,3,4,5,6,7,8], 255, true, true),
    
    // Edge cases
    ([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1], [0,0,0,0,0,0,0,1], 1, true, true),
    ([255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255], [255,255,255,255,255,255,255,255], 254, true, false),
    
    // Invalid cases
    (Array::make(16, 0), [1,2,3,4,5,6,7,8], 1, false, true),
    ([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16], Array::make(8, 0), 1, false, true),
  ]
  
  let mut i = 0
  while i < test_vectors.length() {
    let (tid, sid, flags, expected_valid, expected_sampled) = test_vectors[i]
    let sc = span_context(tid, sid, flags)
    
    assert_eq(sc.is_valid(), expected_valid)
    assert_eq(sc.is_sampled(), expected_sampled)
    
    // Additional validation for valid contexts
    if expected_valid {
      assert_eq(sc.trace_id, tid)
      assert_eq(sc.span_id, sid)
      assert_eq(sc.trace_flags, flags)
      
      // Verify hex conversion doesn't crash and produces expected format
      let tid_hex = sc.trace_id_hex()
      let sid_hex = sc.span_id_hex()
      
      assert_eq(tid_hex.length(), 32) // 16 bytes * 2 hex chars
      assert_eq(sid_hex.length(), 16)  // 8 bytes * 2 hex chars
    }
    
    i = i + 1
  }
}