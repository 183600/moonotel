// Tests for various byte patterns in trace and span IDs

test "hex_byte_00" {
  assert_eq(bytes_to_hex([0x00]), "00")
}

test "hex_byte_ff" {
  assert_eq(bytes_to_hex([0xFF]), "ff")
}

test "hex_byte_0f" {
  assert_eq(bytes_to_hex([0x0F]), "0f")
}

test "hex_byte_f0" {
  assert_eq(bytes_to_hex([0xF0]), "f0")
}

test "hex_two_bytes" {
  assert_eq(bytes_to_hex([0x12, 0x34]), "1234")
}

test "hex_ascending" {
  assert_eq(bytes_to_hex([0x00, 0x11, 0x22]), "001122")
}

test "hex_descending" {
  assert_eq(bytes_to_hex([0xFF, 0xEE, 0xDD]), "ffeedd")
}

test "hex_alternating" {
  assert_eq(bytes_to_hex([0xAA, 0x55, 0xAA]), "aa55aa")
}

test "trace_id_min_valid" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let ctx = span_context(trace_id, span_id, 0)
  assert_true(ctx.is_valid())
}

test "trace_id_max_valid" {
  let trace_id = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let ctx = span_context(trace_id, span_id, 0)
  assert_true(ctx.is_valid())
}

test "span_id_min_valid" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let ctx = span_context(trace_id, span_id, 0)
  assert_true(ctx.is_valid())
}

test "span_id_max_valid" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [255, 255, 255, 255, 255, 255, 255, 255]
  let ctx = span_context(trace_id, span_id, 0)
  assert_true(ctx.is_valid())
}

test "trace_flags_lsb_check_0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let ctx = span_context(trace_id, span_id, 0b00000000)
  assert_false(ctx.is_sampled())
}

test "trace_flags_lsb_check_1" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let ctx = span_context(trace_id, span_id, 0b00000001)
  assert_true(ctx.is_sampled())
}

test "trace_flags_msb_only" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let ctx = span_context(trace_id, span_id, 0b10000000)
  assert_false(ctx.is_sampled())
}

test "trace_flags_all_except_lsb" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let ctx = span_context(trace_id, span_id, 0b11111110)
  assert_false(ctx.is_sampled())
}

test "context_invalid_zero_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let ctx = span_context(trace_id, span_id, 1)
  assert_false(ctx.is_valid())
}

test "context_invalid_zero_span_id" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let ctx = span_context(trace_id, span_id, 1)
  assert_false(ctx.is_valid())
}

test "context_invalid_both_zero" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let ctx = span_context(trace_id, span_id, 1)
  assert_false(ctx.is_valid())
}

test "is_zero_empty_array" {
  assert_true(is_zero([]))
}

test "is_zero_single_zero" {
  assert_true(is_zero([0]))
}

test "is_zero_multiple_zeros" {
  assert_true(is_zero([0, 0, 0, 0]))
}

test "is_zero_single_nonzero" {
  assert_false(is_zero([1]))
}

test "is_zero_mixed_with_one_nonzero" {
  assert_false(is_zero([0, 0, 1, 0]))
}

test "bytes_to_hex_empty" {
  assert_eq(bytes_to_hex([]), "")
}

test "bytes_to_hex_single" {
  assert_eq(bytes_to_hex([42]), "2a")
}

test "bytes_to_hex_two" {
  assert_eq(bytes_to_hex([171, 205]), "abcd")
}

test "byte_to_hex_char_all_values" {
  assert_eq(byte_to_hex_char(0), "0")
  assert_eq(byte_to_hex_char(1), "1")
  assert_eq(byte_to_hex_char(9), "9")
  assert_eq(byte_to_hex_char(10), "a")
  assert_eq(byte_to_hex_char(15), "f")
}
