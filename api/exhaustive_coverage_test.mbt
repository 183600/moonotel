// Exhaustive coverage tests for remaining scenarios

// More trace flag combinations
test "trace_flags_5" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 5)
  assert_true(sc.is_sampled())
}

test "trace_flags_6" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 6)
  assert_false(sc.is_sampled())
}

test "trace_flags_7" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 7)
  assert_true(sc.is_sampled())
}

test "trace_flags_8" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 8)
  assert_false(sc.is_sampled())
}

test "trace_flags_9" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 9)
  assert_true(sc.is_sampled())
}

test "trace_flags_15" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 15)
  assert_true(sc.is_sampled())
}

test "trace_flags_16" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 16)
  assert_false(sc.is_sampled())
}

test "trace_flags_31" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 31)
  assert_true(sc.is_sampled())
}

test "trace_flags_32" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 32)
  assert_false(sc.is_sampled())
}

test "trace_flags_63" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 63)
  assert_true(sc.is_sampled())
}

test "trace_flags_64" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 64)
  assert_false(sc.is_sampled())
}

test "trace_flags_127" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 127)
  assert_true(sc.is_sampled())
}

// More hex encoding patterns
test "bytes_to_hex_squares" {
  assert_eq(bytes_to_hex([1, 4, 9, 16, 25, 36, 49, 64]), "0104091019243140")
}

test "bytes_to_hex_cubes" {
  assert_eq(bytes_to_hex([1, 8, 27, 64, 125]), "01081b407d")
}

test "bytes_to_hex_triangular_numbers" {
  assert_eq(bytes_to_hex([1, 3, 6, 10, 15, 21, 28, 36]), "0103060a0f151c24")
}

test "bytes_to_hex_byte_127" {
  assert_eq(bytes_to_hex([127]), "7f")
}

test "bytes_to_hex_byte_128" {
  assert_eq(bytes_to_hex([128]), "80")
}

test "bytes_to_hex_byte_129" {
  assert_eq(bytes_to_hex([129]), "81")
}

test "bytes_to_hex_byte_191" {
  assert_eq(bytes_to_hex([191]), "bf")
}

test "bytes_to_hex_byte_192" {
  assert_eq(bytes_to_hex([192]), "c0")
}

test "bytes_to_hex_byte_223" {
  assert_eq(bytes_to_hex([223]), "df")
}

test "bytes_to_hex_byte_224" {
  assert_eq(bytes_to_hex([224]), "e0")
}

// More trace ID patterns
test "trace_id_first_half_nonzero" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "trace_id_second_half_nonzero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_id_first_half_nonzero" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_id_second_half_nonzero" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

// More boundary tests
test "trace_id_length_1" {
  let trace_id = [1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "trace_id_length_2" {
  let trace_id = [1, 2]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "trace_id_length_8" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_id_length_1" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_id_length_2" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "span_id_length_4" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 3, 4]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

// More is_zero tests
test "is_zero_2_elements" {
  assert_true(is_zero([0, 0]))
}

test "is_zero_3_elements" {
  assert_true(is_zero([0, 0, 0]))
}

test "is_zero_4_elements" {
  assert_true(is_zero([0, 0, 0, 0]))
}

test "is_zero_8_elements" {
  assert_true(is_zero([0, 0, 0, 0, 0, 0, 0, 0]))
}

test "is_zero_16_elements" {
  assert_true(is_zero([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
}

test "is_zero_32_elements" {
  let arr = Array::make(32, 0)
  assert_true(is_zero(arr))
}

test "is_zero_64_elements" {
  let arr = Array::make(64, 0)
  assert_true(is_zero(arr))
}

test "is_zero_128_elements" {
  let arr = Array::make(128, 0)
  assert_true(is_zero(arr))
}

// Combined scenarios
test "valid_context_with_mixed_bytes" {
  let trace_id = [11, 22, 33, 44, 55, 66, 77, 88, 99, 110, 121, 132, 143, 154, 165, 176]
  let span_id = [200, 211, 222, 233, 244, 255, 100, 111]
  let sc = span_context(trace_id, span_id, 127)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "valid_context_with_odd_trace_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 33)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "valid_context_with_even_trace_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 34)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

// Hex encoding with specific patterns
test "bytes_to_hex_three_bytes" {
  assert_eq(bytes_to_hex([0xAB, 0xCD, 0xEF]), "abcdef")
}

test "bytes_to_hex_four_bytes" {
  assert_eq(bytes_to_hex([0x12, 0x34, 0x56, 0x78]), "12345678")
}

test "bytes_to_hex_five_bytes" {
  assert_eq(bytes_to_hex([0x90, 0xAB, 0xCD, 0xEF, 0x01]), "90abcdef01")
}

test "bytes_to_hex_six_bytes" {
  assert_eq(bytes_to_hex([0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54]), "fedcba987654")
}

test "bytes_to_hex_seven_bytes" {
  assert_eq(bytes_to_hex([1, 2, 3, 4, 5, 6, 7]), "01020304050607")
}

// More invalid span context tests
test "invalid_span_context_is_not_sampled" {
  let sc = invalid_span_context()
  assert_false(sc.is_sampled())
}

test "invalid_span_context_hex_formats" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_id_hex().length(), 32)
  assert_eq(sc.span_id_hex().length(), 16)
}

test "invalid_span_context_all_zeros_in_hex" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
}

// More comprehensive trace ID tests
test "trace_id_byte_increments" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_id_byte_increments" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [10, 20, 30, 40, 50, 60, 70, 80]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

// More byte_to_hex_char tests with out of range values
test "byte_to_hex_char_negative_large" {
  assert_eq(byte_to_hex_char(-9999), "0")
}

test "byte_to_hex_char_positive_large" {
  assert_eq(byte_to_hex_char(9999), "0")
}

test "byte_to_hex_char_20" {
  assert_eq(byte_to_hex_char(20), "0")
}

test "byte_to_hex_char_30" {
  assert_eq(byte_to_hex_char(30), "0")
}

test "byte_to_hex_char_50" {
  assert_eq(byte_to_hex_char(50), "0")
}

test "byte_to_hex_char_99" {
  assert_eq(byte_to_hex_char(99), "0")
}

// Complex multi-field validation
test "span_context_all_fields_valid" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags, 1)
  assert_eq(sc.trace_id_hex().length(), 32)
  assert_eq(sc.span_id_hex().length(), 16)
}

test "span_context_some_fields_valid" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_flags, 1)
}

// Edge cases for arrays
test "is_zero_negative_values" {
  assert_false(is_zero([-1]))
}

test "is_zero_mixed_positive_negative" {
  assert_false(is_zero([0, 0, -1, 0]))
}

// Additional hex conversions
test "bytes_to_hex_single_0x7F" {
  assert_eq(bytes_to_hex([0x7F]), "7f")
}

test "bytes_to_hex_single_0x80" {
  assert_eq(bytes_to_hex([0x80]), "80")
}

test "bytes_to_hex_single_0x3F" {
  assert_eq(bytes_to_hex([0x3F]), "3f")
}

test "bytes_to_hex_single_0x40" {
  assert_eq(bytes_to_hex([0x40]), "40")
}
