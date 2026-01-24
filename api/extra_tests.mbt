
test "byte_to_hex_char_exhaustive" {
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

test "byte_to_hex_char_out_of_bounds" {
  assert_eq(byte_to_hex_char(-1), "0")
  assert_eq(byte_to_hex_char(16), "0")
  assert_eq(byte_to_hex_char(256), "0")
}

test "bytes_to_hex_empty" {
  assert_eq(bytes_to_hex([]), "")
}

test "bytes_to_hex_single" {
  assert_eq(bytes_to_hex([0]), "00")
  assert_eq(bytes_to_hex([1]), "01")
  assert_eq(bytes_to_hex([15]), "0f")
  assert_eq(bytes_to_hex([16]), "10")
  assert_eq(bytes_to_hex([255]), "ff")
}

test "bytes_to_hex_double" {
  assert_eq(bytes_to_hex([0, 0]), "0000")
  assert_eq(bytes_to_hex([255, 255]), "ffff")
  assert_eq(bytes_to_hex([0x12, 0x34]), "1234")
}

test "is_zero_exhaustive" {
  assert_true(is_zero([]))
  assert_true(is_zero([0]))
  assert_true(is_zero([0, 0]))
  assert_true(is_zero([0, 0, 0]))
  assert_true(is_zero(Array::make(16, 0)))
  assert_false(is_zero([1]))
  assert_false(is_zero([0, 1]))
  assert_false(is_zero([1, 0]))
  assert_false(is_zero([0, 0, 1]))
  assert_false(is_zero(Array::make(16, 1)))
}

test "span_context_creation" {
  let tid = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  let sid = [1,2,3,4,5,6,7,8]
  let sc = span_context(tid, sid, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id, tid)
  assert_eq(sc.span_id, sid)
  assert_eq(sc.trace_flags, 1)
}

test "span_context_invalid_tid_length" {
  let tid = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
  let sid = [1,2,3,4,5,6,7,8]
  let sc = span_context(tid, sid, 1)
  assert_false(sc.is_valid())
}

test "span_context_invalid_sid_length" {
  let tid = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  let sid = [1,2,3,4,5,6,7]
  let sc = span_context(tid, sid, 1)
  assert_false(sc.is_valid())
}

test "span_context_zero_tid" {
  let tid = Array::make(16, 0)
  let sid = [1,2,3,4,5,6,7,8]
  let sc = span_context(tid, sid, 1)
  assert_false(sc.is_valid())
}

test "span_context_zero_sid" {
  let tid = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  let sid = Array::make(8, 0)
  let sc = span_context(tid, sid, 1)
  assert_false(sc.is_valid())
}

test "span_context_is_sampled" {
  let tid = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  let sid = [1,2,3,4,5,6,7,8]
  assert_true(span_context(tid, sid, 1).is_sampled())
  assert_false(span_context(tid, sid, 0).is_sampled())
  assert_true(span_context(tid, sid, 255).is_sampled())
  assert_false(span_context(tid, sid, 254).is_sampled())
}

test "span_context_hex_output" {
  let tid = [0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10]
  let sid = [0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0]
  let sc = span_context(tid, sid, 1)
  assert_eq(sc.trace_id_hex(), "0123456789abcdeffedcba9876543210")
  assert_eq(sc.span_id_hex(), "123456789abcdef0")
}

test "invalid_span_context_is_invalid" {
  let sc = invalid_span_context()
  assert_false(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
}

test "large_number_of_contexts" {
  let mut i = 0
  while i < 100 {
    let tid = Array::make(16, i + 1)
    let sid = Array::make(8, i + 1)
    let sc = span_context(tid, sid, 1)
    assert_true(sc.is_valid())
    i = i + 1
  }
}

test "bytes_to_hex_all_bytes" {
  let mut i = 0
  while i < 256 {
    let hex = bytes_to_hex([i])
    assert_eq(hex.length(), 2)
    i = i + 1
  }
}

test "is_zero_various_lengths" {
  assert_true(is_zero(Array::make(0, 0)))
  assert_true(is_zero(Array::make(1, 0)))
  assert_true(is_zero(Array::make(2, 0)))
  assert_true(is_zero(Array::make(4, 0)))
  assert_true(is_zero(Array::make(8, 0)))
  assert_true(is_zero(Array::make(16, 0)))
  assert_true(is_zero(Array::make(32, 0)))
  
  assert_false(is_zero([1]))
  assert_false(is_zero([0, 1]))
  assert_false(is_zero([0, 0, 1]))
  assert_false(is_zero([0, 0, 0, 1]))
}

test "span_context_is_sampled_edge_cases" {
  let tid = [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]
  let sid = [1,1,1,1,1,1,1,1]
  
  // Only the least significant bit matters for sampled flag
  let mut i = 0
  while i < 256 {
    let sc = span_context(tid, sid, i)
    if (i & 1) != 0 {
      assert_true(sc.is_sampled())
    } else {
      assert_false(sc.is_sampled())
    }
    i = i + 1
  }
}

test "span_context_invalid_trace_id_lengths" {
  let sid = [1,2,3,4,5,6,7,8]
  assert_false(span_context(Array::make(0, 1), sid, 1).is_valid())
  assert_false(span_context(Array::make(1, 1), sid, 1).is_valid())
  assert_false(span_context(Array::make(15, 1), sid, 1).is_valid())
  assert_false(span_context(Array::make(17, 1), sid, 1).is_valid())
}

test "span_context_invalid_span_id_lengths" {
  let tid = Array::make(16, 1)
  assert_false(span_context(tid, Array::make(0, 1), 1).is_valid())
  assert_false(span_context(tid, Array::make(1, 1), 1).is_valid())
  assert_false(span_context(tid, Array::make(7, 1), 1).is_valid())
  assert_false(span_context(tid, Array::make(9, 1), 1).is_valid())
}

test "span_context_immutability_behavior" {
  let tid = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  let sid = [1,2,3,4,5,6,7,8]
  let sc = span_context(tid, sid, 1)
  
  // Modify the original array
  tid[0] = 255
  sid[0] = 255
  
  // In current implementation, sc.trace_id reflects the change because it's the same array
  assert_eq(sc.trace_id[0], 255)
  assert_eq(sc.span_id[0], 255)
}

test "byte_to_hex_char_negative" {
  assert_eq(byte_to_hex_char(-1), "0")
  assert_eq(byte_to_hex_char(-100), "0")
}

test "bytes_to_hex_multiple_bytes" {
  assert_eq(bytes_to_hex([0xDE, 0xAD, 0xBE, 0xEF]), "deadbeef")
}
