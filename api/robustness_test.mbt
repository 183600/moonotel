// Robustness and stress tests for SpanContext

test "create_many_span_contexts" {
  let mut count = 0
  while count < 100 {
    let mut tid = Array::make(16, 0)
    let mut sid = Array::make(8, 0)
    tid[0] = count % 256
    sid[0] = count % 256
    let sc = span_context(tid, sid, count % 2)
    assert_true(sc.is_valid())
    count = count + 1
  }
}

test "alternating_valid_invalid_contexts" {
  let mut i = 0
  while i < 50 {
    let valid_tid = Array::make(16, 1)
    let valid_sid = Array::make(8, 1)
    let valid_sc = span_context(valid_tid, valid_sid, 0)
    assert_true(valid_sc.is_valid())
    
    let invalid_sc = invalid_span_context()
    assert_false(invalid_sc.is_valid())
    
    i = i + 1
  }
}

test "span_context_with_varying_trace_flags" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  let mut flags = 0
  while flags < 256 {
    let sc = span_context(tid, sid, flags)
    let expected_sampled = (flags & 1) != 0
    assert_eq(sc.is_sampled(), expected_sampled)
    flags = flags + 2
  }
}

test "hex_conversion_consistency" {
  let mut byte_val = 0
  while byte_val < 256 {
    let hex = bytes_to_hex([byte_val])
    assert_eq(hex.length(), 2)
    byte_val = byte_val + 1
  }
}

test "is_zero_with_progressive_fill" {
  let mut arr = Array::make(16, 0)
  assert_true(is_zero(arr))
  
  let mut i = 0
  while i < 16 {
    arr[i] = 1
    assert_false(is_zero(arr))
    arr[i] = 0
    assert_true(is_zero(arr))
    i = i + 1
  }
}

test "span_context_trace_id_variations" {
  let sid = Array::make(8, 1)
  
  let mut i = 0
  while i < 256 {
    let mut tid = Array::make(16, 0)
    tid[0] = i
    if i > 0 {
      let sc = span_context(tid, sid, 0)
      assert_true(sc.is_valid())
    }
    i = i + 1
  }
}

test "span_context_span_id_variations" {
  let tid = Array::make(16, 1)
  
  let mut i = 0
  while i < 256 {
    let mut sid = Array::make(8, 0)
    sid[0] = i
    if i > 0 {
      let sc = span_context(tid, sid, 0)
      assert_true(sc.is_valid())
    }
    i = i + 1
  }
}

test "mixed_zero_nonzero_patterns" {
  let patterns = [
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  ]
  
  let sid = Array::make(8, 1)
  let mut i = 0
  while i < patterns.length() {
    let sc = span_context(patterns[i], sid, 0)
    assert_true(sc.is_valid())
    i = i + 1
  }
}

test "hex_encoding_all_nibbles_combined" {
  let all_nibbles = [
    0x01, 0x23, 0x45, 0x67,
    0x89, 0xAB, 0xCD, 0xEF
  ]
  let hex = bytes_to_hex(all_nibbles)
  assert_eq(hex, "0123456789abcdef")
}

test "trace_flags_bit_masking" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  // Test various bit patterns
  let test_flags = [
    0b00000000,  // 0
    0b00000001,  // 1
    0b00000011,  // 3
    0b00000111,  // 7
    0b00001111,  // 15
    0b00011111,  // 31
    0b00111111,  // 63
    0b01111111,  // 127
    0b11111111,  // 255
  ]
  
  let mut i = 0
  while i < test_flags.length() {
    let sc = span_context(tid, sid, test_flags[i])
    let expected = (test_flags[i] & 1) != 0
    assert_eq(sc.is_sampled(), expected)
    i = i + 1
  }
}

test "large_scale_hex_conversion" {
  let mut size = 1
  while size <= 64 {
    let arr = Array::make(size, 0xA5)
    let hex = bytes_to_hex(arr)
    assert_eq(hex.length(), size * 2)
    size = size * 2
  }
}

test "span_context_repeated_creation" {
  let tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let mut count = 0
  while count < 100 {
    let sc = span_context(tid, sid, count % 256)
    assert_true(sc.is_valid())
    assert_eq(sc.trace_id_hex().length(), 32)
    assert_eq(sc.span_id_hex().length(), 16)
    count = count + 1
  }
}
