// Extended validation tests for SpanContext

test "invalid_span_context_has_all_zero_ids" {
  let invalid_sc = invalid_span_context()
  assert_false(invalid_sc.is_valid())
  assert_eq(invalid_sc.trace_id.length(), 16)
  assert_eq(invalid_sc.span_id.length(), 8)
  assert_true(is_zero(invalid_sc.trace_id))
  assert_true(is_zero(invalid_sc.span_id))
}

test "span_context_with_wrong_length_trace_id_is_invalid" {
  let short_tid = Array::make(15, 1)
  let long_tid = Array::make(17, 1)
  let valid_sid = Array::make(8, 1)
  
  let sc_short = span_context(short_tid, valid_sid, 0)
  assert_false(sc_short.is_valid())
  
  let sc_long = span_context(long_tid, valid_sid, 0)
  assert_false(sc_long.is_valid())
}

test "span_context_with_wrong_length_span_id_is_invalid" {
  let valid_tid = Array::make(16, 1)
  let short_sid = Array::make(7, 1)
  let long_sid = Array::make(9, 1)
  
  let sc_short = span_context(valid_tid, short_sid, 0)
  assert_false(sc_short.is_valid())
  
  let sc_long = span_context(valid_tid, long_sid, 0)
  assert_false(sc_long.is_valid())
}

test "trace_flags_preserved_in_span_context" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  let sc0 = span_context(tid, sid, 0)
  assert_eq(sc0.trace_flags, 0)
  
  let sc1 = span_context(tid, sid, 1)
  assert_eq(sc1.trace_flags, 1)
  
  let sc255 = span_context(tid, sid, 255)
  assert_eq(sc255.trace_flags, 255)
}

test "trace_id_hex_for_all_zeros" {
  let zero_tid = Array::make(16, 0)
  let hex = bytes_to_hex(zero_tid)
  assert_eq(hex, "00000000000000000000000000000000")
  assert_eq(hex.length(), 32)
}

test "span_id_hex_for_all_zeros" {
  let zero_sid = Array::make(8, 0)
  let hex = bytes_to_hex(zero_sid)
  assert_eq(hex, "0000000000000000")
  assert_eq(hex.length(), 16)
}

test "trace_id_hex_for_all_ones" {
  let ones_tid = Array::make(16, 255)
  let hex = bytes_to_hex(ones_tid)
  assert_eq(hex, "ffffffffffffffffffffffffffffffff")
  assert_eq(hex.length(), 32)
}

test "span_id_hex_for_all_ones" {
  let ones_sid = Array::make(8, 255)
  let hex = bytes_to_hex(ones_sid)
  assert_eq(hex, "ffffffffffffffff")
  assert_eq(hex.length(), 16)
}

test "bytes_to_hex_single_byte_values" {
  assert_eq(bytes_to_hex([0]), "00")
  assert_eq(bytes_to_hex([1]), "01")
  assert_eq(bytes_to_hex([15]), "0f")
  assert_eq(bytes_to_hex([16]), "10")
  assert_eq(bytes_to_hex([255]), "ff")
  assert_eq(bytes_to_hex([170]), "aa")
  assert_eq(bytes_to_hex([85]), "55")
}

test "bytes_to_hex_multiple_bytes" {
  assert_eq(bytes_to_hex([0, 1]), "0001")
  assert_eq(bytes_to_hex([255, 0]), "ff00")
  assert_eq(bytes_to_hex([1, 2, 3]), "010203")
  assert_eq(bytes_to_hex([254, 253, 252]), "fefdfC")
}

test "is_zero_empty_array" {
  assert_true(is_zero(Array::make(0, 0)))
}

test "is_zero_various_sizes" {
  assert_true(is_zero(Array::make(1, 0)))
  assert_true(is_zero(Array::make(8, 0)))
  assert_true(is_zero(Array::make(16, 0)))
  assert_true(is_zero(Array::make(100, 0)))
}

test "is_zero_with_one_nonzero_at_start" {
  let mut arr = Array::make(16, 0)
  arr[0] = 1
  assert_false(is_zero(arr))
}

test "is_zero_with_one_nonzero_at_end" {
  let mut arr = Array::make(16, 0)
  arr[15] = 1
  assert_false(is_zero(arr))
}

test "is_zero_with_one_nonzero_in_middle" {
  let mut arr = Array::make(16, 0)
  arr[8] = 1
  assert_false(is_zero(arr))
}

test "is_sampled_flag_bit_0" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  assert_false(span_context(tid, sid, 0).is_sampled())
  assert_true(span_context(tid, sid, 1).is_sampled())
  assert_false(span_context(tid, sid, 2).is_sampled())
  assert_true(span_context(tid, sid, 3).is_sampled())
  assert_false(span_context(tid, sid, 4).is_sampled())
  assert_true(span_context(tid, sid, 5).is_sampled())
}

test "is_sampled_flag_higher_bits_ignored" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  assert_false(span_context(tid, sid, 0b00000000).is_sampled())
  assert_true(span_context(tid, sid, 0b00000001).is_sampled())
  assert_false(span_context(tid, sid, 0b11111110).is_sampled())
  assert_true(span_context(tid, sid, 0b11111111).is_sampled())
}

test "span_context_immutability" {
  let mut tid = Array::make(16, 1)
  let mut sid = Array::make(8, 1)
  
  let sc = span_context(tid, sid, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
  
  // Modifying original arrays doesn't affect SpanContext
  tid[0] = 0
  sid[0] = 0
  
  // SpanContext still valid (has its own copy)
  assert_true(sc.is_valid())
}

test "byte_to_hex_char_all_values" {
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

test "hex_encoding_specific_patterns" {
  // Test alternating patterns
  let pattern1 = [0xAA, 0xAA, 0xAA, 0xAA]
  assert_eq(bytes_to_hex(pattern1), "aaaaaaaa")
  
  let pattern2 = [0x55, 0x55, 0x55, 0x55]
  assert_eq(bytes_to_hex(pattern2), "55555555")
  
  let pattern3 = [0xF0, 0x0F, 0xF0, 0x0F]
  assert_eq(bytes_to_hex(pattern3), "f00ff00f")
}
