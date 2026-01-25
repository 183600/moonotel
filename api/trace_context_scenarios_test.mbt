// Additional trace context scenario tests

test "span_context_trace_flags_bitmask" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  // Test each bit in trace_flags
  let mut i = 0
  while i < 8 {
    let flag = 1 << i
    let sc = span_context(tid, sid, flag)
    assert_eq(sc.trace_flags, flag)
    // Only bit 0 controls sampling
    if i == 0 {
      assert_true(sc.is_sampled())
    } else {
      assert_false(sc.is_sampled())
    }
    i = i + 1
  }
}

test "trace_id_with_alternating_bytes" {
  let tid = [0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255]
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
  let hex = sc.trace_id_hex()
  assert_eq(hex, "00ff00ff00ff00ff00ff00ff00ff00ff")
}

test "span_id_with_incrementing_bytes" {
  let tid = Array::make(16, 1)
  let sid = [0, 1, 2, 3, 4, 5, 6, 7]
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
  let hex = sc.span_id_hex()
  assert_eq(hex, "0001020304050607")
}

test "multiple_span_contexts_same_trace" {
  let tid = Array::make(16, 1)
  let sid1 = Array::make(8, 1)
  let sid2 = Array::make(8, 2)
  let sid3 = Array::make(8, 3)
  
  let sc1 = span_context(tid, sid1, 0)
  let sc2 = span_context(tid, sid2, 0)
  let sc3 = span_context(tid, sid3, 0)
  
  // All should have same trace ID
  assert_eq(sc1.trace_id_hex(), sc2.trace_id_hex())
  assert_eq(sc2.trace_id_hex(), sc3.trace_id_hex())
  
  // All should have different span IDs
  assert_false(sc1.span_id_hex() == sc2.span_id_hex())
  assert_false(sc2.span_id_hex() == sc3.span_id_hex())
  assert_false(sc1.span_id_hex() == sc3.span_id_hex())
}

test "trace_flags_combined_bits" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  // Test combinations with sampling bit (bit 0)
  assert_true(span_context(tid, sid, 1).is_sampled())
  assert_true(span_context(tid, sid, 3).is_sampled())
  assert_true(span_context(tid, sid, 5).is_sampled())
  assert_true(span_context(tid, sid, 7).is_sampled())
  
  // Without sampling bit
  assert_false(span_context(tid, sid, 0).is_sampled())
  assert_false(span_context(tid, sid, 2).is_sampled())
  assert_false(span_context(tid, sid, 4).is_sampled())
  assert_false(span_context(tid, sid, 6).is_sampled())
}

test "trace_id_first_byte_boundary" {
  let sid = Array::make(8, 1)
  
  let mut i = 1
  while i < 256 {
    let tid = Array::make(16, 0)
    tid[0] = i
    let sc = span_context(tid, sid, 0)
    assert_true(sc.is_valid())
    i = i + 1
  }
}

test "span_id_first_byte_boundary" {
  let tid = Array::make(16, 1)
  
  let mut i = 1
  while i < 256 {
    let sid = Array::make(8, 0)
    sid[0] = i
    let sc = span_context(tid, sid, 0)
    assert_true(sc.is_valid())
    i = i + 1
  }
}

test "hex_encoding_all_values" {
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

test "bytes_to_hex_single_byte_variations" {
  let mut i = 0
  while i < 256 {
    let bytes = [i]
    let hex = bytes_to_hex(bytes)
    assert_eq(hex.length(), 2)
    assert_eq(bytes.length(), 1)
    i = i + 1
  }
}

test "invalid_span_context_properties" {
  let invalid = invalid_span_context()
  assert_false(invalid.is_valid())
  assert_false(invalid.is_sampled())
  assert_eq(invalid.trace_flags, 0)
  assert_eq(invalid.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(invalid.span_id_hex(), "0000000000000000")
}

test "trace_id_with_single_byte_variations" {
  let sid = Array::make(8, 1)
  
  let mut pos = 0
  while pos < 16 {
    let tid = Array::make(16, 0)
    tid[pos] = 42
    let sc = span_context(tid, sid, 0)
    assert_true(sc.is_valid())
    
    let hex = sc.trace_id_hex()
    assert_eq(hex.length(), 32)
    
    pos = pos + 1
  }
}

test "span_id_with_single_byte_variations" {
  let tid = Array::make(16, 1)
  
  let mut pos = 0
  while pos < 8 {
    let sid = Array::make(8, 0)
    sid[pos] = 99
    let sc = span_context(tid, sid, 0)
    assert_true(sc.is_valid())
    
    let hex = sc.span_id_hex()
    assert_eq(hex.length(), 16)
    
    pos = pos + 1
  }
}

test "is_zero_with_special_patterns" {
  // All zeros
  assert_true(is_zero([0, 0, 0, 0]))
  
  // First byte non-zero
  assert_false(is_zero([1, 0, 0, 0]))
  
  // Last byte non-zero
  assert_false(is_zero([0, 0, 0, 1]))
  
  // Middle byte non-zero
  assert_false(is_zero([0, 1, 0, 0]))
  
  // All non-zero
  assert_false(is_zero([1, 2, 3, 4]))
}

test "span_context_trace_flags_preservation" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  let mut flags = 0
  while flags < 256 {
    let sc = span_context(tid, sid, flags)
    assert_eq(sc.trace_flags, flags)
    flags = flags + 1
  }
}

test "bytes_to_hex_empty_and_small_arrays" {
  // Single byte patterns
  assert_eq(bytes_to_hex([0]), "00")
  assert_eq(bytes_to_hex([255]), "ff")
  assert_eq(bytes_to_hex([128]), "80")
  
  // Two byte patterns
  assert_eq(bytes_to_hex([0, 0]), "0000")
  assert_eq(bytes_to_hex([255, 255]), "ffff")
  assert_eq(bytes_to_hex([0, 255]), "00ff")
}
