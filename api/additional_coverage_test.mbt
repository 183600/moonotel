// Additional test coverage for SpanContext functionality

test "byte_to_hex_char_boundary_0" {
  assert_eq(byte_to_hex_char(0), "0")
}

test "byte_to_hex_char_boundary_15" {
  assert_eq(byte_to_hex_char(15), "f")
}

test "byte_to_hex_char_all_decimal_digits" {
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
}

test "byte_to_hex_char_all_hex_letters" {
  assert_eq(byte_to_hex_char(10), "a")
  assert_eq(byte_to_hex_char(11), "b")
  assert_eq(byte_to_hex_char(12), "c")
  assert_eq(byte_to_hex_char(13), "d")
  assert_eq(byte_to_hex_char(14), "e")
  assert_eq(byte_to_hex_char(15), "f")
}

test "byte_to_hex_char_out_of_range_16" {
  assert_eq(byte_to_hex_char(16), "0")
}

test "byte_to_hex_char_out_of_range_100" {
  assert_eq(byte_to_hex_char(100), "0")
}

test "byte_to_hex_char_out_of_range_negative" {
  assert_eq(byte_to_hex_char(-1), "0")
}

test "bytes_to_hex_comprehensive_1" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7]
  assert_eq(bytes_to_hex(bytes), "0001020304050607")
}

test "bytes_to_hex_comprehensive_2" {
  let bytes = [8, 9, 10, 11, 12, 13, 14, 15]
  assert_eq(bytes_to_hex(bytes), "08090a0b0c0d0e0f")
}

test "bytes_to_hex_high_nibble_0" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  assert_eq(bytes_to_hex(bytes), "000102030405060708090a0b0c0d0e0f")
}

test "bytes_to_hex_high_nibble_1" {
  let bytes = [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
  assert_eq(bytes_to_hex(bytes), "101112131415161718191a1b1c1d1e1f")
}

test "bytes_to_hex_high_nibble_f" {
  let bytes = [240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255]
  assert_eq(bytes_to_hex(bytes), "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
}

test "is_zero_empty_edge_case" {
  let empty : Array[Int] = []
  assert_true(is_zero(empty))
}

test "is_zero_single_zero" {
  let arr = [0]
  assert_true(is_zero(arr))
}

test "is_zero_single_nonzero" {
  let arr = [1]
  assert_false(is_zero(arr))
}

test "is_zero_two_zeros" {
  let arr = [0, 0]
  assert_true(is_zero(arr))
}

test "is_zero_two_first_nonzero" {
  let arr = [1, 0]
  assert_false(is_zero(arr))
}

test "is_zero_two_second_nonzero" {
  let arr = [0, 1]
  assert_false(is_zero(arr))
}

test "is_zero_long_array_all_zeros" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_true(is_zero(arr))
}

test "is_zero_long_array_last_nonzero" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  assert_false(is_zero(arr))
}

test "span_context_trace_flags_bit_0" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_sampled())
}

test "span_context_trace_flags_bit_1" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 2)
  assert_false(sc.is_sampled())
}

test "span_context_trace_flags_bit_0_and_1" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 3)
  assert_true(sc.is_sampled())
}

test "span_context_trace_flags_all_even" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 254)
  assert_false(sc.is_sampled())
}

test "span_context_trace_flags_all_odd" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 255)
  assert_true(sc.is_sampled())
}

test "invalid_span_context_properties" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_flags, 0)
  assert_false(sc.is_valid())
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_id.length(), 16)
  assert_eq(sc.span_id.length(), 8)
}

test "span_context_with_empty_arrays" {
  let trace_id : Array[Int] = []
  let span_id : Array[Int] = []
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_trace_id_empty" {
  let trace_id : Array[Int] = []
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_span_id_empty" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id : Array[Int] = []
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_exact_length_validation" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "hex_encoding_byte_0x00" {
  let bytes = [0x00]
  assert_eq(bytes_to_hex(bytes), "00")
}

test "hex_encoding_byte_0xff" {
  let bytes = [0xff]
  assert_eq(bytes_to_hex(bytes), "ff")
}

test "hex_encoding_byte_0x0f" {
  let bytes = [0x0f]
  assert_eq(bytes_to_hex(bytes), "0f")
}

test "hex_encoding_byte_0xf0" {
  let bytes = [0xf0]
  assert_eq(bytes_to_hex(bytes), "f0")
}

test "hex_encoding_byte_0xaa" {
  let bytes = [0xaa]
  assert_eq(bytes_to_hex(bytes), "aa")
}

test "hex_encoding_byte_0x55" {
  let bytes = [0x55]
  assert_eq(bytes_to_hex(bytes), "55")
}

test "span_context_hex_methods_consistency" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.trace_id_hex().length(), 32)
  assert_eq(sc.span_id_hex().length(), 16)
}

test "invalid_span_context_hex_output" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
}

test "trace_id_all_same_byte" {
  let trace_id = [123, 123, 123, 123, 123, 123, 123, 123, 123, 123, 123, 123, 123, 123, 123, 123]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b")
}

test "span_id_all_same_byte" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [100, 100, 100, 100, 100, 100, 100, 100]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "6464646464646464")
}
