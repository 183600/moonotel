// Additional edge case and boundary tests for SpanContext

// Test boundary values for trace_id and span_id
test "trace_id_first_byte_zero_others_nonzero" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "trace_id_last_byte_zero_others_nonzero" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_id_first_byte_zero_others_nonzero" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [0, 17, 18, 19, 20, 21, 22, 23]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "span_id_last_byte_zero_others_nonzero" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

// Test trace flags bit manipulation
test "trace_flags_sampled_bit" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]

  let sc1 = span_context(trace_id, span_id, 0)
  assert_false(sc1.is_sampled())

  let sc2 = span_context(trace_id, span_id, 1)
  assert_true(sc2.is_sampled())

  let sc3 = span_context(trace_id, span_id, 2)
  assert_false(sc3.is_sampled())

  let sc4 = span_context(trace_id, span_id, 3)
  assert_true(sc4.is_sampled())
}

test "trace_flags_odd_even" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]

  let mut i = 0
  while i < 10 {
    let sc = span_context(trace_id, span_id, i)
    let should_sample = (i % 2) != 0
    assert_eq(sc.is_sampled(), should_sample)
    i = i + 1
  }
}

// Test hex encoding edge cases
test "hex_encoding_all_zeros_invalid" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
}

test "hex_encoding_single_nonzero_trace" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000001")
}

test "hex_encoding_single_nonzero_span" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.span_id_hex(), "0000000000000001")
}

test "hex_encoding_boundary_values" {
  let trace_id_min = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id_min = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc_min = span_context(trace_id_min, span_id_min, 1)
  assert_eq(sc_min.trace_id_hex(), "00000000000000000000000000000001")
  assert_eq(sc_min.span_id_hex(), "0000000000000001")

  let trace_id_max = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id_max = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc_max = span_context(trace_id_max, span_id_max, 1)
  assert_eq(sc_max.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(sc_max.span_id_hex(), "ffffffffffffffff")
}

// Test is_zero function with various patterns
test "is_zero_empty_array" {
  let empty = []
  assert_true(is_zero(empty))
}

test "is_zero_single_zero" {
  let single = [0]
  assert_true(is_zero(single))
}

test "is_zero_single_nonzero" {
  let single = [1]
  assert_false(is_zero(single))
}

test "is_zero_middle_nonzero" {
  let arr = [0, 0, 1, 0, 0]
  assert_false(is_zero(arr))
}

test "is_zero_last_nonzero" {
  let arr = [0, 0, 0, 0, 1]
  assert_false(is_zero(arr))
}

test "is_zero_first_nonzero" {
  let arr = [1, 0, 0, 0, 0]
  assert_false(is_zero(arr))
}

// Test context validity with edge cases
test "context_validity_independence" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]

  let sc1 = span_context(trace_id, span_id, 0)
  assert_true(sc1.is_valid())
  assert_false(sc1.is_sampled())

  let sc2 = span_context(trace_id, span_id, 1)
  assert_true(sc2.is_valid())
  assert_true(sc2.is_sampled())

  let sc3 = span_context(trace_id, span_id, 255)
  assert_true(sc3.is_valid())
  assert_true(sc3.is_sampled())
}

test "context_validity_wrong_trace_length" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "context_validity_wrong_span_length" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "context_validity_both_wrong_length" {
  let trace_id = [1, 2, 3, 4]
  let span_id = [16, 17, 18, 19]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

// Test hex conversion helper function
test "byte_to_hex_char_zero" {
  assert_eq(byte_to_hex_char(0), "0")
}

test "byte_to_hex_char_nine" {
  assert_eq(byte_to_hex_char(9), "9")
}

test "byte_to_hex_char_ten" {
  assert_eq(byte_to_hex_char(10), "a")
}

test "byte_to_hex_char_fifteen" {
  assert_eq(byte_to_hex_char(15), "f")
}

test "byte_to_hex_char_out_of_range" {
  assert_eq(byte_to_hex_char(16), "0")
  assert_eq(byte_to_hex_char(255), "0")
}

test "bytes_to_hex_single_byte" {
  let bytes = [10]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0a")
}

test "bytes_to_hex_two_bytes" {
  let bytes = [10, 15]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0a0f")
}

test "bytes_to_hex_all_bytes" {
  let bytes = [0, 1, 10, 15, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "00010a0fff")
}

test "bytes_to_hex_empty_array" {
  let bytes = []
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "")
}

// Test sampling with various flag values
test "sampling_flag_values" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]

  let sc1 = span_context(trace_id, span_id, 1)
  assert_true(sc1.is_sampled())

  let sc2 = span_context(trace_id, span_id, 2)
  assert_false(sc2.is_sampled())

  let sc3 = span_context(trace_id, span_id, 3)
  assert_true(sc3.is_sampled())

  let sc4 = span_context(trace_id, span_id, 4)
  assert_false(sc4.is_sampled())

  let sc5 = span_context(trace_id, span_id, 5)
  assert_true(sc5.is_sampled())

  let sc6 = span_context(trace_id, span_id, 6)
  assert_false(sc6.is_sampled())

  let sc7 = span_context(trace_id, span_id, 7)
  assert_true(sc7.is_sampled())

  let sc8 = span_context(trace_id, span_id, 8)
  assert_false(sc8.is_sampled())
}

test "sampling_with_upper_bits_set" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]

  let sc1 = span_context(trace_id, span_id, 0b10)
  assert_false(sc1.is_sampled())

  let sc2 = span_context(trace_id, span_id, 0b100)
  assert_false(sc2.is_sampled())

  let sc3 = span_context(trace_id, span_id, 0b1000)
  assert_false(sc3.is_sampled())
}

// Test pattern repetition in IDs
test "repeating_pattern_trace_id" {
  let trace_id = [1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "01020304010203040102030401020304")
}

test "repeating_pattern_span_id" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [1, 2, 1, 2, 1, 2, 1, 2]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0102010201020102")
}

// Test byte ordering
test "byte_order_preserved" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.trace_id_hex(), "0102030405060708090a0b0c0d0e0f10")
  assert_eq(sc.span_id_hex(), "1112131415161718")
}
