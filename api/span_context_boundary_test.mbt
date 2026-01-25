// Boundary tests for SpanContext helper functions

// Test byte_to_hex_char for all possible values (0-15)
test "byte_to_hex_char_zero" {
  assert_eq(byte_to_hex_char(0), "0")
}

test "byte_to_hex_char_one" {
  assert_eq(byte_to_hex_char(1), "1")
}

test "byte_to_hex_char_two" {
  assert_eq(byte_to_hex_char(2), "2")
}

test "byte_to_hex_char_three" {
  assert_eq(byte_to_hex_char(3), "3")
}

test "byte_to_hex_char_four" {
  assert_eq(byte_to_hex_char(4), "4")
}

test "byte_to_hex_char_five" {
  assert_eq(byte_to_hex_char(5), "5")
}

test "byte_to_hex_char_six" {
  assert_eq(byte_to_hex_char(6), "6")
}

test "byte_to_hex_char_seven" {
  assert_eq(byte_to_hex_char(7), "7")
}

test "byte_to_hex_char_eight" {
  assert_eq(byte_to_hex_char(8), "8")
}

test "byte_to_hex_char_nine" {
  assert_eq(byte_to_hex_char(9), "9")
}

test "byte_to_hex_char_ten" {
  assert_eq(byte_to_hex_char(10), "a")
}

test "byte_to_hex_char_eleven" {
  assert_eq(byte_to_hex_char(11), "b")
}

test "byte_to_hex_char_twelve" {
  assert_eq(byte_to_hex_char(12), "c")
}

test "byte_to_hex_char_thirteen" {
  assert_eq(byte_to_hex_char(13), "d")
}

test "byte_to_hex_char_fourteen" {
  assert_eq(byte_to_hex_char(14), "e")
}

test "byte_to_hex_char_fifteen" {
  assert_eq(byte_to_hex_char(15), "f")
}

test "byte_to_hex_char_out_of_range_low" {
  assert_eq(byte_to_hex_char(-1), "0")
}

test "byte_to_hex_char_out_of_range_high" {
  assert_eq(byte_to_hex_char(16), "0")
}

test "byte_to_hex_char_out_of_range_very_high" {
  assert_eq(byte_to_hex_char(255), "0")
}

// Test is_zero for various array sizes and patterns
test "is_zero_empty_array" {
  let arr : Array[Int] = []
  assert_true(is_zero(arr))
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

test "is_zero_two_second_nonzero" {
  let arr = [0, 1]
  assert_false(is_zero(arr))
}

test "is_zero_two_first_nonzero" {
  let arr = [1, 0]
  assert_false(is_zero(arr))
}

test "is_zero_three_zeros" {
  let arr = [0, 0, 0]
  assert_true(is_zero(arr))
}

test "is_zero_middle_nonzero" {
  let arr = [0, 1, 0]
  assert_false(is_zero(arr))
}

test "is_zero_eight_zeros" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 0]
  assert_true(is_zero(arr))
}

test "is_zero_eight_last_nonzero" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 1]
  assert_false(is_zero(arr))
}

test "is_zero_sixteen_zeros" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_true(is_zero(arr))
}

test "is_zero_sixteen_first_nonzero" {
  let arr = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  assert_false(is_zero(arr))
}

test "is_zero_trace_id_size" {
  let arr = Array::make(16, 0)
  assert_true(is_zero(arr))
}

test "is_zero_span_id_size" {
  let arr = Array::make(8, 0)
  assert_true(is_zero(arr))
}

test "is_zero_max_byte" {
  let arr = [255]
  assert_false(is_zero(arr))
}

test "is_zero_min_byte" {
  let arr = [0]
  assert_true(is_zero(arr))
}

test "is_zero_all_ones" {
  let arr = [1, 1, 1, 1]
  assert_false(is_zero(arr))
}

// Test bytes_to_hex for various patterns
test "bytes_to_hex_empty" {
  let arr : Array[Int] = []
  assert_eq(bytes_to_hex(arr), "")
}

test "bytes_to_hex_single_zero" {
  let arr = [0]
  assert_eq(bytes_to_hex(arr), "00")
}

test "bytes_to_hex_single_one" {
  let arr = [1]
  assert_eq(bytes_to_hex(arr), "01")
}

test "bytes_to_hex_single_fifteen" {
  let arr = [15]
  assert_eq(bytes_to_hex(arr), "0f")
}

test "bytes_to_hex_single_sixteen" {
  let arr = [16]
  assert_eq(bytes_to_hex(arr), "10")
}

test "bytes_to_hex_single_max" {
  let arr = [255]
  assert_eq(bytes_to_hex(arr), "ff")
}

test "bytes_to_hex_two_zeros" {
  let arr = [0, 0]
  assert_eq(bytes_to_hex(arr), "0000")
}

test "bytes_to_hex_two_max" {
  let arr = [255, 255]
  assert_eq(bytes_to_hex(arr), "ffff")
}

test "bytes_to_hex_two_mixed" {
  let arr = [0x12, 0x34]
  assert_eq(bytes_to_hex(arr), "1234")
}

test "bytes_to_hex_eight_zeros" {
  let arr = [0, 0, 0, 0, 0, 0, 0, 0]
  assert_eq(bytes_to_hex(arr), "0000000000000000")
}

test "bytes_to_hex_sequence" {
  let arr = [1, 2, 3, 4, 5, 6, 7, 8]
  assert_eq(bytes_to_hex(arr), "0102030405060708")
}

test "bytes_to_hex_span_id_size" {
  let arr = Array::make(8, 0)
  assert_eq(bytes_to_hex(arr), "0000000000000000")
}

test "bytes_to_hex_trace_id_size_zeros" {
  let arr = Array::make(16, 0)
  assert_eq(bytes_to_hex(arr), "00000000000000000000000000000000")
}

test "bytes_to_hex_trace_id_size_pattern" {
  let arr = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10]
  assert_eq(bytes_to_hex(arr), "0102030405060708090a0b0c0d0e0f10")
}

test "bytes_to_hex_all_zeros" {
  let arr = [0, 0, 0, 0]
  assert_eq(bytes_to_hex(arr), "00000000")
}

test "bytes_to_hex_all_max" {
  let arr = [255, 255, 255, 255]
  assert_eq(bytes_to_hex(arr), "ffffffff")
}

test "bytes_to_hex_alternating" {
  let arr = [0, 255, 0, 255]
  assert_eq(bytes_to_hex(arr), "00ff00ff")
}

// Test SpanContext with trace_flags edge cases
test "span_context_trace_flags_zero" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_sampled())
}

test "span_context_trace_flags_one" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_sampled())
}

test "span_context_trace_flags_two" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 2)
  assert_false(sc.is_sampled())
}

test "span_context_trace_flags_three" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 3)
  assert_true(sc.is_sampled())
}

test "span_context_trace_flags_eight" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 8)
  assert_false(sc.is_sampled())
}

test "span_context_trace_flags_nine" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 9)
  assert_true(sc.is_sampled())
}

test "span_context_trace_flags_255" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 255)
  assert_true(sc.is_sampled())
}

test "span_context_trace_flags_254" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 254)
  assert_false(sc.is_sampled())
}

test "span_context_trace_flags_odd_even" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  // Even numbers: not sampled
  let sc1 = span_context(trace_id, span_id, 100)
  assert_false(sc1.is_sampled())
  
  // Odd numbers: sampled
  let sc2 = span_context(trace_id, span_id, 101)
  assert_true(sc2.is_sampled())
}

test "span_context_trace_flags_bitwise" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let sc1 = span_context(trace_id, span_id, 0b00000001)
  assert_true(sc1.is_sampled())
  
  let sc2 = span_context(trace_id, span_id, 0b00000010)
  assert_false(sc2.is_sampled())
  
  let sc3 = span_context(trace_id, span_id, 0b00000011)
  assert_true(sc3.is_sampled())
  
  let sc4 = span_context(trace_id, span_id, 0b00000100)
  assert_false(sc4.is_sampled())
}

// Test SpanContext validity with various trace_id patterns
test "span_context_valid_with_single_nonzero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_context_invalid_trace_id_all_zero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_context_invalid_span_id_all_zero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_context_invalid_both_zero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_context_trace_id_all_max" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
}

test "span_context_span_id_all_max" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "ffffffffffffffff")
}

test "span_context_hex_representation_min" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000001")
  assert_eq(sc.span_id_hex(), "0000000000000001")
}

test "span_context_hex_representation_mid" {
  let trace_id = [0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  let span_id = [0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "80000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "8000000000000000")
}

test "span_context_boundary_byte_values" {
  // Test with boundary byte values
  let trace_id = [0, 1, 127, 128, 255, 0, 1, 255, 0, 1, 127, 128, 255, 0, 1, 255]
  let span_id = [0, 1, 127, 128, 255, 0, 1, 255]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00017f80ff0001ff00017f80ff0001ff")
  assert_eq(sc.span_id_hex(), "00017f80ff0001ff")
}

test "span_context_repeated_pattern" {
  let trace_id = [0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa]
  let span_id = [0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
  assert_eq(sc.span_id_hex(), "bbbbbbbbbbbbbbbb")
}

test "span_context_sequential_pattern" {
  let trace_id = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]
  let span_id = [0x01, 0x12, 0x23, 0x34, 0x45, 0x56, 0x67, 0x78]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00112233445566778899aabbccddeeff")
  assert_eq(sc.span_id_hex(), "0112233445566778")
  assert_true(sc.is_sampled())
}

test "span_context_alternating_bits" {
  let trace_id = [0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa]
  let span_id = [0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "55aa55aa55aa55aa55aa55aa55aa55aa")
  assert_eq(sc.span_id_hex(), "55aa55aa55aa55aa")
}

// Test edge cases for SpanContext creation
test "span_context_preserves_fields" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let flags = 42
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_flags, 42)
  assert_eq(sc.trace_id_hex(), "0102030405060708090a0b0c0d0e0f10")
  assert_eq(sc.span_id_hex(), "0102030405060708")
  assert_false(sc.is_sampled())  // 42 is even, 42 & 1 = 0
}

test "span_context_invalid_preserves_fields" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let flags = 0  // Use 0 to not be sampled
  let sc = span_context(trace_id, span_id, flags)
  assert_false(sc.is_valid())
  assert_eq(sc.trace_flags, 0)
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
  assert_false(sc.is_sampled())
}

test "span_context_trace_flags_max" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let flags = 2147483647  // Max Int
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "span_context_trace_flags_large_even" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let flags = 2147483646  // Max Int - 1
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "bytes_to_hex_preserves_case" {
  // Verify lowercase output (per memory requirement)
  let arr = [10, 11, 12, 13, 14, 15]
  assert_eq(bytes_to_hex(arr), "0a0b0c0d0e0f")
}

test "bytes_to_hex_case_upper_boundaries" {
  let arr = [0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x1a, 0x1b]
  assert_eq(bytes_to_hex(arr), "0a0b0c0d0e0f1a1b")
}

test "is_zero_large_array" {
  let arr = Array::make(100, 0)
  assert_true(is_zero(arr))
}

test "is_zero_large_array_middle_nonzero" {
  let arr = Array::make(100, 0)
  arr[50] = 1
  assert_false(is_zero(arr))
}
