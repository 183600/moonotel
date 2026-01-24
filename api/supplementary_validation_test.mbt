// Supplementary validation tests for SpanContext

test "trace_id_alternating_bits" {
  let tid = [0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55]
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "aa55aa55aa55aa55aa55aa55aa55aa55")
}

test "span_id_alternating_bits" {
  let tid = Array::make(16, 1)
  let sid = [0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55]
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "aa55aa55aa55aa55")
}

test "trace_id_fibonacci_like_sequence" {
  let tid = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 121, 98, 219]
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
}

test "span_id_fibonacci_like_sequence" {
  let tid = Array::make(16, 1)
  let sid = [1, 1, 2, 3, 5, 8, 13, 21]
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
}

test "bytes_to_hex_with_ascii_boundaries" {
  assert_eq(bytes_to_hex([0x20]), "20")
  assert_eq(bytes_to_hex([0x7E]), "7e")
  assert_eq(bytes_to_hex([0x30]), "30")
  assert_eq(bytes_to_hex([0x39]), "39")
}

test "trace_flags_power_of_two" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  assert_true(span_context(tid, sid, 1).is_sampled())
  assert_false(span_context(tid, sid, 2).is_sampled())
  assert_false(span_context(tid, sid, 4).is_sampled())
  assert_false(span_context(tid, sid, 8).is_sampled())
  assert_false(span_context(tid, sid, 16).is_sampled())
  assert_false(span_context(tid, sid, 32).is_sampled())
  assert_false(span_context(tid, sid, 64).is_sampled())
  assert_false(span_context(tid, sid, 128).is_sampled())
}

test "trace_flags_combined_bits" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  assert_true(span_context(tid, sid, 0b00000001).is_sampled())
  assert_true(span_context(tid, sid, 0b00000011).is_sampled())
  assert_true(span_context(tid, sid, 0b00000101).is_sampled())
  assert_true(span_context(tid, sid, 0b11111111).is_sampled())
  assert_false(span_context(tid, sid, 0b00000000).is_sampled())
  assert_false(span_context(tid, sid, 0b00000010).is_sampled())
  assert_false(span_context(tid, sid, 0b11111110).is_sampled())
}

test "invalid_span_context_properties" {
  let invalid = invalid_span_context()
  assert_false(invalid.is_valid())
  assert_false(invalid.is_sampled())
  assert_eq(invalid.trace_id.length(), 16)
  assert_eq(invalid.span_id.length(), 8)
  assert_eq(invalid.trace_flags, 0)
}

test "invalid_span_context_hex_output" {
  let invalid = invalid_span_context()
  assert_eq(invalid.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(invalid.span_id_hex(), "0000000000000000")
}

test "span_context_with_mixed_zero_nonzero" {
  let tid = [1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0]
  let sid = [1, 0, 2, 0, 3, 0, 4, 0]
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
}

test "is_zero_with_various_sizes" {
  assert_true(is_zero(Array::make(1, 0)))
  assert_true(is_zero(Array::make(8, 0)))
  assert_true(is_zero(Array::make(16, 0)))
  assert_true(is_zero(Array::make(32, 0)))
  assert_true(is_zero(Array::make(64, 0)))
}

test "is_zero_empty_array" {
  assert_true(is_zero([]))
}

test "is_zero_single_element_nonzero" {
  assert_false(is_zero([1]))
  assert_false(is_zero([255]))
  assert_false(is_zero([128]))
}

test "bytes_to_hex_nibble_combinations" {
  assert_eq(bytes_to_hex([0x00]), "00")
  assert_eq(bytes_to_hex([0x0A]), "0a")
  assert_eq(bytes_to_hex([0xA0]), "a0")
  assert_eq(bytes_to_hex([0xAA]), "aa")
}

test "hex_with_utf8_like_boundaries" {
  assert_eq(bytes_to_hex([0x7F]), "7f")
  assert_eq(bytes_to_hex([0x80]), "80")
  assert_eq(bytes_to_hex([0xBF]), "bf")
  assert_eq(bytes_to_hex([0xC0]), "c0")
}

test "span_context_with_descending_values" {
  let tid = [255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240]
  let sid = [255, 254, 253, 252, 251, 250, 249, 248]
  let sc = span_context(tid, sid, 255)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "span_context_with_ascending_values" {
  let tid = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let sid = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(tid, sid, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "byte_to_hex_char_all_valid_values" {
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

test "hex_with_repeating_nibbles" {
  assert_eq(bytes_to_hex([0x00, 0x00]), "0000")
  assert_eq(bytes_to_hex([0x11, 0x11]), "1111")
  assert_eq(bytes_to_hex([0x22, 0x22]), "2222")
  assert_eq(bytes_to_hex([0x33, 0x33]), "3333")
  assert_eq(bytes_to_hex([0x44, 0x44]), "4444")
  assert_eq(bytes_to_hex([0x55, 0x55]), "5555")
  assert_eq(bytes_to_hex([0x66, 0x66]), "6666")
  assert_eq(bytes_to_hex([0x77, 0x77]), "7777")
  assert_eq(bytes_to_hex([0x88, 0x88]), "8888")
  assert_eq(bytes_to_hex([0x99, 0x99]), "9999")
  assert_eq(bytes_to_hex([0xAA, 0xAA]), "aaaa")
  assert_eq(bytes_to_hex([0xBB, 0xBB]), "bbbb")
  assert_eq(bytes_to_hex([0xCC, 0xCC]), "cccc")
  assert_eq(bytes_to_hex([0xDD, 0xDD]), "dddd")
  assert_eq(bytes_to_hex([0xEE, 0xEE]), "eeee")
  assert_eq(bytes_to_hex([0xFF, 0xFF]), "ffff")
}

test "span_context_trace_id_length_validation" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_eq(sc.trace_id.length(), 16)
}

test "span_context_span_id_length_validation" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_eq(sc.span_id.length(), 8)
}

test "hex_output_length_for_trace_id" {
  let tid = Array::make(16, 0xAB)
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_eq(sc.trace_id_hex().length(), 32)
}

test "hex_output_length_for_span_id" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 0xCD)
  let sc = span_context(tid, sid, 0)
  assert_eq(sc.span_id_hex().length(), 16)
}

test "is_zero_first_element_nonzero" {
  let arr = Array::make(16, 0)
  arr[0] = 1
  assert_false(is_zero(arr))
}

test "is_zero_middle_element_nonzero" {
  let arr = Array::make(16, 0)
  arr[8] = 1
  assert_false(is_zero(arr))
}

test "is_zero_last_element_nonzero" {
  let arr = Array::make(16, 0)
  arr[15] = 1
  assert_false(is_zero(arr))
}

test "bytes_to_hex_single_byte_all_values" {
  let mut i = 0
  while i < 256 {
    let hex = bytes_to_hex([i])
    assert_eq(hex.length(), 2)
    i = i + 1
  }
}

test "span_context_with_mirror_pattern" {
  let tid = [1, 2, 3, 4, 5, 6, 7, 8, 8, 7, 6, 5, 4, 3, 2, 1]
  let sid = [1, 2, 3, 4, 4, 3, 2, 1]
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
}

test "span_context_flags_preserve_value" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  let sc1 = span_context(tid, sid, 42)
  assert_eq(sc1.trace_flags, 42)
  
  let sc2 = span_context(tid, sid, 123)
  assert_eq(sc2.trace_flags, 123)
}

test "hex_with_classic_test_patterns" {
  assert_eq(bytes_to_hex([0xDE, 0xAD]), "dead")
  assert_eq(bytes_to_hex([0xBE, 0xEF]), "beef")
  assert_eq(bytes_to_hex([0xCA, 0xFE]), "cafe")
  assert_eq(bytes_to_hex([0xBA, 0xBE]), "babe")
}

test "is_zero_alternating_zeros_nonzeros" {
  assert_false(is_zero([0, 1, 0, 1]))
  assert_false(is_zero([1, 0, 1, 0]))
}

test "span_context_with_prime_numbers" {
  let tid = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53]
  let sid = [2, 3, 5, 7, 11, 13, 17, 19]
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
}

test "bytes_to_hex_boundary_transitions" {
  assert_eq(bytes_to_hex([0x0F, 0x10]), "0f10")
  assert_eq(bytes_to_hex([0x7F, 0x80]), "7f80")
  assert_eq(bytes_to_hex([0xFE, 0xFF]), "feff")
}

test "trace_flags_sampled_bit_isolation" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  assert_true(span_context(tid, sid, 0b00000001).is_sampled())
  assert_true(span_context(tid, sid, 0b11111111).is_sampled())
  assert_false(span_context(tid, sid, 0b11111110).is_sampled())
  assert_false(span_context(tid, sid, 0b00000000).is_sampled())
}

test "hex_with_gray_code_pattern" {
  assert_eq(bytes_to_hex([0b00000000]), "00")
  assert_eq(bytes_to_hex([0b00000001]), "01")
  assert_eq(bytes_to_hex([0b00000011]), "03")
  assert_eq(bytes_to_hex([0b00000010]), "02")
  assert_eq(bytes_to_hex([0b00000110]), "06")
}

test "span_context_all_ones_trace_id" {
  let tid = Array::make(16, 0xFF)
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
}

test "span_context_all_ones_span_id" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 0xFF)
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

test "bytes_to_hex_complementary_pairs" {
  assert_eq(bytes_to_hex([0x00, 0xFF]), "00ff")
  assert_eq(bytes_to_hex([0x0F, 0xF0]), "0ff0")
  assert_eq(bytes_to_hex([0x33, 0xCC]), "33cc")
  assert_eq(bytes_to_hex([0x55, 0xAA]), "55aa")
}

test "is_zero_very_small_nonzero_value" {
  assert_false(is_zero([1]))
  assert_false(is_zero([0, 0, 0, 1]))
}

test "span_context_checksum_like_values" {
  let tid = [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]
  let sid = [0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00]
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
}

test "hex_with_nybble_rotation" {
  assert_eq(bytes_to_hex([0x12]), "12")
  assert_eq(bytes_to_hex([0x23]), "23")
  assert_eq(bytes_to_hex([0x34]), "34")
  assert_eq(bytes_to_hex([0x45]), "45")
  assert_eq(bytes_to_hex([0x56]), "56")
  assert_eq(bytes_to_hex([0x67]), "67")
  assert_eq(bytes_to_hex([0x78]), "78")
  assert_eq(bytes_to_hex([0x89]), "89")
  assert_eq(bytes_to_hex([0x9A]), "9a")
  assert_eq(bytes_to_hex([0xAB]), "ab")
  assert_eq(bytes_to_hex([0xBC]), "bc")
  assert_eq(bytes_to_hex([0xCD]), "cd")
  assert_eq(bytes_to_hex([0xDE]), "de")
  assert_eq(bytes_to_hex([0xEF]), "ef")
}

test "span_context_with_zero_flags" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_eq(sc.trace_flags, 0)
  assert_false(sc.is_sampled())
}

test "span_context_with_max_flags" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 255)
  assert_eq(sc.trace_flags, 255)
  assert_true(sc.is_sampled())
}

test "bytes_to_hex_octet_boundaries" {
  assert_eq(bytes_to_hex([127]), "7f")
  assert_eq(bytes_to_hex([128]), "80")
  assert_eq(bytes_to_hex([255]), "ff")
  assert_eq(bytes_to_hex([0]), "00")
}

test "is_zero_multiple_positions_nonzero" {
  assert_false(is_zero([1, 0, 1]))
  assert_false(is_zero([0, 1, 0, 1, 0]))
  assert_false(is_zero([1, 1, 1, 1]))
}

test "span_context_trace_id_span_id_independence" {
  let tid1 = Array::make(16, 1)
  let sid1 = Array::make(8, 2)
  let sc1 = span_context(tid1, sid1, 0)
  
  let tid2 = Array::make(16, 3)
  let sid2 = Array::make(8, 4)
  let sc2 = span_context(tid2, sid2, 0)
  
  assert_true(sc1.is_valid())
  assert_true(sc2.is_valid())
}

test "hex_with_doubling_pattern" {
  assert_eq(bytes_to_hex([1, 2, 4, 8]), "01020408")
  assert_eq(bytes_to_hex([16, 32, 64, 128]), "10204080")
}

test "span_context_odd_sampled_flags" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  assert_true(span_context(tid, sid, 1).is_sampled())
  assert_true(span_context(tid, sid, 7).is_sampled())
  assert_true(span_context(tid, sid, 15).is_sampled())
  assert_true(span_context(tid, sid, 31).is_sampled())
  assert_true(span_context(tid, sid, 63).is_sampled())
  assert_true(span_context(tid, sid, 127).is_sampled())
  assert_true(span_context(tid, sid, 255).is_sampled())
}

test "span_context_even_not_sampled_flags" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  assert_false(span_context(tid, sid, 0).is_sampled())
  assert_false(span_context(tid, sid, 6).is_sampled())
  assert_false(span_context(tid, sid, 14).is_sampled())
  assert_false(span_context(tid, sid, 30).is_sampled())
  assert_false(span_context(tid, sid, 62).is_sampled())
  assert_false(span_context(tid, sid, 126).is_sampled())
  assert_false(span_context(tid, sid, 254).is_sampled())
}

test "bytes_to_hex_with_magic_numbers" {
  assert_eq(bytes_to_hex([0x42]), "42")
  assert_eq(bytes_to_hex([0x13, 0x37]), "1337")
  assert_eq(bytes_to_hex([0xC0, 0xFF, 0xEE]), "c0ffee")
}

test "is_zero_with_large_value_at_end" {
  let arr = Array::make(100, 0)
  arr[99] = 255
  assert_false(is_zero(arr))
}

test "span_context_hex_case_consistency" {
  let tid = [0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0, 0x11, 0x22, 0x33, 0x44, 0x55]
  let sid = Array::make(8, 0xAF)
  let sc = span_context(tid, sid, 0)
  
  let trace_hex = sc.trace_id_hex()
  let span_hex = sc.span_id_hex()
  
  assert_eq(trace_hex, "abcdef123456789abcdef01122334455")
  assert_eq(span_hex, "afafafafafafafaf")
}

test "byte_to_hex_char_negative_boundary" {
  assert_eq(byte_to_hex_char(-1), "0")
  assert_eq(byte_to_hex_char(-100), "0")
  assert_eq(byte_to_hex_char(-255), "0")
}

test "byte_to_hex_char_positive_boundary" {
  assert_eq(byte_to_hex_char(16), "0")
  assert_eq(byte_to_hex_char(17), "0")
  assert_eq(byte_to_hex_char(256), "0")
  assert_eq(byte_to_hex_char(1000), "0")
}

test "span_context_multiple_valid_instances" {
  let sc1 = span_context(Array::make(16, 1), Array::make(8, 1), 0)
  let sc2 = span_context(Array::make(16, 2), Array::make(8, 2), 1)
  let sc3 = span_context(Array::make(16, 3), Array::make(8, 3), 2)
  
  assert_true(sc1.is_valid())
  assert_true(sc2.is_valid())
  assert_true(sc3.is_valid())
  
  assert_false(sc1.is_sampled())
  assert_true(sc2.is_sampled())
  assert_false(sc3.is_sampled())
}

test "hex_with_bit_masking_patterns" {
  assert_eq(bytes_to_hex([0xFF & 0x0F]), "0f")
  assert_eq(bytes_to_hex([0xFF & 0xF0]), "f0")
  assert_eq(bytes_to_hex([0xAA & 0x55]), "00")
  assert_eq(bytes_to_hex([0xAA & 0xFF]), "aa")
}

test "is_zero_comprehensive_false_cases" {
  assert_false(is_zero([255]))
  assert_false(is_zero([0, 255]))
  assert_false(is_zero([255, 0]))
  assert_false(is_zero([128, 64, 32]))
}

test "span_context_validation_trace_id_zeros" {
  let tid = Array::make(16, 0)
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_false(sc.is_valid())
}

test "span_context_validation_span_id_zeros" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 0)
  let sc = span_context(tid, sid, 0)
  assert_false(sc.is_valid())
}

test "span_context_validation_both_zeros" {
  let tid = Array::make(16, 0)
  let sid = Array::make(8, 0)
  let sc = span_context(tid, sid, 0)
  assert_false(sc.is_valid())
}

test "bytes_to_hex_array_length_consistency" {
  assert_eq(bytes_to_hex([1]).length(), 2)
  assert_eq(bytes_to_hex([1, 2]).length(), 4)
  assert_eq(bytes_to_hex([1, 2, 3]).length(), 6)
  assert_eq(bytes_to_hex([1, 2, 3, 4]).length(), 8)
}

test "trace_flags_bit_field_behavior" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  let sc_bit0 = span_context(tid, sid, 0b00000001)
  let sc_bit1 = span_context(tid, sid, 0b00000010)
  let sc_both = span_context(tid, sid, 0b00000011)
  
  assert_true(sc_bit0.is_sampled())
  assert_false(sc_bit1.is_sampled())
  assert_true(sc_both.is_sampled())
}

test "hex_symmetry_check" {
  let forward = [1, 2, 3, 4]
  let reverse = [4, 3, 2, 1]
  
  assert_eq(bytes_to_hex(forward), "01020304")
  assert_eq(bytes_to_hex(reverse), "04030201")
}

test "is_zero_edge_case_single_zero" {
  assert_true(is_zero([0]))
}

test "span_context_realistic_trace_id" {
  let tid = [0x4b, 0xf9, 0x2f, 0x35, 0x77, 0xb3, 0x4d, 0xa6, 0xa3, 0xce, 0x92, 0x9d, 0x0e, 0x0e, 0x47, 0x26]
  let sid = [0x00, 0xf0, 0x67, 0xaa, 0x0b, 0xa9, 0x02, 0xb7]
  let sc = span_context(tid, sid, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "span_context_realistic_not_sampled" {
  let tid = [0x4b, 0xf9, 0x2f, 0x35, 0x77, 0xb3, 0x4d, 0xa6, 0xa3, 0xce, 0x92, 0x9d, 0x0e, 0x0e, 0x47, 0x26]
  let sid = [0x00, 0xf0, 0x67, 0xaa, 0x0b, 0xa9, 0x02, 0xb7]
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "bytes_to_hex_monotonic_increase" {
  let arr = [10, 20, 30, 40, 50, 60, 70, 80]
  let hex = bytes_to_hex(arr)
  assert_eq(hex, "0a141e28323c4650")
}

test "bytes_to_hex_monotonic_decrease" {
  let arr = [80, 70, 60, 50, 40, 30, 20, 10]
  let hex = bytes_to_hex(arr)
  assert_eq(hex, "50463c32281e140a")
}

test "span_context_flags_preservation_full_range" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  let mut flag = 0
  while flag < 256 {
    let sc = span_context(tid, sid, flag)
    assert_eq(sc.trace_flags, flag)
    flag = flag + 1
  }
}

test "is_zero_middle_nonzero_element" {
  let arr = [0, 0, 0, 0, 1, 0, 0, 0]
  assert_false(is_zero(arr))
}

test "hex_with_repetitive_increments" {
  assert_eq(bytes_to_hex([0, 1, 2]), "000102")
  assert_eq(bytes_to_hex([10, 11, 12]), "0a0b0c")
  assert_eq(bytes_to_hex([20, 21, 22]), "141516")
}
