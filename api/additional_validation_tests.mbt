// Additional validation tests for SpanContext and hex utilities

test "span_context_trace_flags_variations" {
  // Test various trace flag values
  let trace_id = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F]
  let span_id = [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17]
  
  let sc0 = span_context(trace_id, span_id, 0)
  assert_true(sc0.is_valid())
  assert_false(sc0.is_sampled())
  
  let sc1 = span_context(trace_id, span_id, 1)
  assert_true(sc1.is_valid())
  assert_true(sc1.is_sampled())
  
  let sc2 = span_context(trace_id, span_id, 2)
  assert_true(sc2.is_valid())
  assert_false(sc2.is_sampled())
  
  let sc3 = span_context(trace_id, span_id, 3)
  assert_true(sc3.is_valid())
  assert_true(sc3.is_sampled())
  
  let sc255 = span_context(trace_id, span_id, 255)
  assert_true(sc255.is_valid())
  assert_true(sc255.is_sampled())
}

test "span_context_partial_zero_trace_id" {
  // Test when only some bytes of trace_id are zero
  let mut trace_id = [0xFF, 0xFF]
  let mut i = 0
  while i < 14 {
    trace_id = trace_id + [0x00]
    i = i + 1
  }
  let span_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_partial_zero_span_id" {
  // Test when only some bytes of span_id are zero
  let trace_id = [0xFF, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F]
  let mut span_id = [0xFF]
  let mut i = 0
  while i < 7 {
    span_id = span_id + [0x00]
    i = i + 1
  }
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_invalid_wrong_lengths" {
  // Test SpanContext with incorrect ID lengths
  let short_trace = [0x01, 0x02, 0x03]
  let span_id = [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17]
  let sc1 = span_context(short_trace, span_id, 1)
  assert_false(sc1.is_valid())
  
  let trace_id = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F]
  let short_span = [0x10, 0x11]
  let sc2 = span_context(trace_id, short_span, 1)
  assert_false(sc2.is_valid())
}

test "is_zero_comprehensive" {
  // Test is_zero with various arrays
  let all_zero = Array::make(16, 0)
  assert_true(is_zero(all_zero))
  
  let non_zero = [0x00, 0x00, 0x00, 0x01]
  assert_false(is_zero(non_zero))
  
  let empty = []
  assert_true(is_zero(empty))
}

test "span_context_id_generation_patterns" {
  // Test various trace/span ID generation patterns
  let trace_pattern1 = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0x00]
  let span_pattern1 = [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0]
  let sc1 = span_context(trace_pattern1, span_pattern1, 1)
  assert_true(sc1.is_valid())
  assert_eq(sc1.trace_id_hex(), "aabbccddeeff11223344556677889900")
  assert_eq(sc1.span_id_hex(), "123456789abcdef0")
  
  let trace_pattern2 = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10]
  let span_pattern2 = [0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88]
  let sc2 = span_context(trace_pattern2, span_pattern2, 0)
  assert_true(sc2.is_valid())
  assert_false(sc2.is_sampled())
}

test "hex_boundary_64_bytes" {
  // Test hex conversion with 64 bytes (typical trace ID size)
  let mut data64 = []
  let mut i = 0
  while i < 64 {
    data64 = data64 + [i]
    i = i + 1
  }
  let hex_result = bytes_to_hex(data64)
  assert_eq(hex_result.length(), 128)
}

test "span_context_trace_flags_boundary" {
  // Test boundary values for trace flags
  let trace_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]
  let span_id = [0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18]
  
  let sc_max = span_context(trace_id, span_id, 2147483647) // max int
  assert_true(sc_max.is_sampled())
}

test "span_context_hex_roundtrip" {
  // Test that converting to hex and back preserves data
  let original_trace = [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0]
  let original_span = [0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10]
  let sc = span_context(original_trace, original_span, 1)
  
  let trace_hex = sc.trace_id_hex()
  let span_hex = sc.span_id_hex()
  
  assert_eq(trace_hex, "123456789abcdef0123456789abcdef0")
  assert_eq(span_hex, "fedcba9876543210")
}

test "bytes_to_hex_special_characters" {
  // Test bytes with special bit patterns
  assert_eq(bytes_to_hex([0b10101010]), "aa")
  assert_eq(bytes_to_hex([0b01010101]), "55")
  assert_eq(bytes_to_hex([0b11110000]), "f0")
  assert_eq(bytes_to_hex([0b00001111]), "0f")
  assert_eq(bytes_to_hex([0b11001100]), "cc")
  assert_eq(bytes_to_hex([0b00110011]), "33")
}

test "span_context_minimal_valid" {
  // Test minimal valid trace_id and span_id (non-zero)
  let trace_id = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]
  let span_id = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_context_maximal_values" {
  // Test with maximal byte values
  let max_trace = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let max_span = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let sc = span_context(max_trace, max_span, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

test "hex_consecutive_zeros" {
  // Test hex conversion with consecutive zeros
  assert_eq(bytes_to_hex([0x00, 0x00, 0x00, 0x00]), "00000000")
  assert_eq(bytes_to_hex([0x00, 0x01, 0x00, 0x02]), "00010002")
  assert_eq(bytes_to_hex([0xFF, 0x00, 0x00, 0xFF]), "ff0000ff")
}

test "span_context_multiple_instances" {
  // Test creating multiple span contexts
  let mut contexts = []
  let mut i = 0
  while i < 10 {
    let trace_id = [i, i + 1, i + 2, i + 3, i + 4, i + 5, i + 6, i + 7, i + 8, i + 9, i + 10, i + 11, i + 12, i + 13, i + 14, i + 15]
    let span_id = [i * 2, i * 2 + 1, i * 2 + 2, i * 2 + 3, i * 2 + 4, i * 2 + 5, i * 2 + 6, i * 2 + 7]
    let sc = span_context(trace_id, span_id, i % 2)
    contexts = contexts + [sc]
    i = i + 1
  }
  
  assert_eq(contexts.length(), 10)
  let mut j = 0
  while j < 10 {
    assert_true(contexts[j].is_valid())
    if j % 2 == 0 {
      assert_false(contexts[j].is_sampled())
    } else {
      assert_true(contexts[j].is_sampled())
    }
    j = j + 1
  }
}

test "hex_byte_values_0_to_255" {
  // Test all byte values from 0 to 255
  let mut all_bytes = []
  let mut i = 0
  while i < 256 {
    all_bytes = all_bytes + [i]
    i = i + 1
  }
  let hex_result = bytes_to_hex(all_bytes)
  assert_eq(hex_result.length(), 512)
}

test "invalid_span_context_properties" {
  // Test properties of invalid span context
  let inv = invalid_span_context()
  assert_false(inv.is_valid())
  assert_false(inv.is_sampled())
  assert_eq(inv.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(inv.span_id_hex(), "0000000000000000")
}

test "span_context_trace_id_hex_various" {
  // Test trace_id_hex with various patterns
  let sc1 = span_context([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F], [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17], 1)
  assert_eq(sc1.trace_id_hex(), "000102030405060708090a0b0c0d0e0f")
  
  let sc2 = span_context([0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0x00], [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF], 0)
  assert_eq(sc2.trace_id_hex(), "ffeeddccbbaa99887766554433221100")
  assert_eq(sc2.span_id_hex(), "0123456789abcdef")
}

test "span_context_singleton_bytes" {
  // Test span contexts with single non-zero byte in various positions
  let mut pos = 0
  while pos < 16 {
    let trace_id = Array::make(16, 0)
    trace_id[pos] = 1
    let span_id = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]
    let sc = span_context(trace_id, span_id, 1)
    assert_true(sc.is_valid())
    pos = pos + 1
  }
  
  let trace_id = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]
  let mut span_pos = 0
  while span_pos < 8 {
    let span_id = Array::make(8, 0)
    span_id[span_pos] = 1
    let sc = span_context(trace_id, span_id, 1)
    assert_true(sc.is_valid())
    span_pos = span_pos + 1
  }
}

test "span_context_is_zero_edge" {
  // Test is_zero with exactly one non-zero byte at different positions
  let trace_only_last = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]
  assert_false(is_zero(trace_only_last))
  
  let trace_all_but_last = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  assert_false(is_zero(trace_all_but_last))
  
  let trace_empty = []
  assert_true(is_zero(trace_empty))
}

test "bytes_to_hex_consistency" {
  // Test consistency of bytes_to_hex output format
  let result = bytes_to_hex([0x0A, 0x0B, 0x0C])
  assert_eq(result, "0a0b0c")
  
  let result2 = bytes_to_hex([0x00, 0x0F, 0xF0, 0xFF])
  assert_eq(result2, "000ff0ff")
  
  // All lowercase
  assert_true(result.has_prefix("0a"))
}

test "span_context_trace_flags_only_lsb" {
  // Test that only the least significant bit matters for sampling
  let trace_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]
  let span_id = [0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18]
  
  // Even numbers (LSB = 0) should not be sampled
  assert_false(span_context(trace_id, span_id, 2).is_sampled())
  assert_false(span_context(trace_id, span_id, 4).is_sampled())
  assert_false(span_context(trace_id, span_id, 100).is_sampled())
  
  // Odd numbers (LSB = 1) should be sampled
  assert_true(span_context(trace_id, span_id, 1).is_sampled())
  assert_true(span_context(trace_id, span_id, 3).is_sampled())
  assert_true(span_context(trace_id, span_id, 101).is_sampled())
}

test "bytes_to_hex_large_repeated_pattern" {
  // Test bytes_to_hex with a large repeated pattern
  let pattern = [0xAB, 0xCD]
  let mut large = []
  let mut i = 0
  while i < 500 {
    large = large + pattern
    i = i + 1
  }
  let hex_result = bytes_to_hex(large)
  assert_eq(hex_result.length(), 2000)
}

test "span_context_first_last_byte_nonzero" {
  // Test when only first and last bytes are non-zero
  let trace_first_last = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF]
  let span_first_last = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF]
  
  let sc = span_context(trace_first_last, span_first_last, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "010000000000000000000000000000ff")
  assert_eq(sc.span_id_hex(), "01000000000000ff")
}

test "is_zero_array_make" {
  // Test is_zero with Array::make
  assert_true(is_zero(Array::make(0, 0)))
  assert_true(is_zero(Array::make(1, 0)))
  assert_true(is_zero(Array::make(10, 0)))
  assert_true(is_zero(Array::make(100, 0)))
  assert_false(is_zero(Array::make(10, 1)))
}
