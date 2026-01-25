
test "is_zero_basic" {
  assert_true(is_zero([0, 0, 0, 0]))
  assert_false(is_zero([0, 0, 1, 0]))
}

test "is_zero_edge" {
  assert_true(is_zero([]))
  assert_false(is_zero([255]))
}

test "bytes_to_hex_single" {
  assert_eq(bytes_to_hex([0]), "00")
  assert_eq(bytes_to_hex([15]), "0f")
  assert_eq(bytes_to_hex([16]), "10")
  assert_eq(bytes_to_hex([255]), "ff")
}

test "bytes_to_hex_multiple" {
  assert_eq(bytes_to_hex([1, 2, 3]), "010203")
  assert_eq(bytes_to_hex([10, 11, 12, 13, 14, 15]), "0a0b0c0d0e0f")
}

test "byte_to_hex_char_all" {
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
  assert_eq(byte_to_hex_char(16), "0") // Default case
}

test "span_context_validity" {
  let valid_tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let valid_sid = [1, 2, 3, 4, 5, 6, 7, 8]
  
  // Valid
  let sc1 = span_context(valid_tid, valid_sid, 0)
  assert_true(sc1.is_valid())
  
  // Invalid trace_id (all zeros)
  let sc2 = span_context(Array::make(16, 0), valid_sid, 0)
  assert_false(sc2.is_valid())
  
  // Invalid span_id (all zeros)
  let sc3 = span_context(valid_tid, Array::make(8, 0), 0)
  assert_false(sc3.is_valid())
  
  // Invalid trace_id length
  let sc4 = span_context([1], valid_sid, 0)
  assert_false(sc4.is_valid())
  
  // Invalid span_id length
  let sc5 = span_context(valid_tid, [1], 0)
  assert_false(sc5.is_valid())
}

test "span_context_sampled" {
  let tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  
  assert_false(span_context(tid, sid, 0).is_sampled())
  assert_true(span_context(tid, sid, 1).is_sampled())
  assert_false(span_context(tid, sid, 2).is_sampled())
  assert_true(span_context(tid, sid, 3).is_sampled())
  assert_true(span_context(tid, sid, 255).is_sampled())
}

test "bytes_to_hex_large_array" {
  let arr = Array::make(100, 255)
  let hex = bytes_to_hex(arr)
  assert_eq(hex.length(), 200)
}

test "is_zero_large_array" {
  let arr = Array::make(100, 0)
  assert_true(is_zero(arr))
  arr[99] = 1
  assert_false(is_zero(arr))
}
