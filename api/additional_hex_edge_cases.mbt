// Additional hex encoding edge case tests

test "hex_single_byte_value_zero" {
  let bytes = [0]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "00")
}

test "hex_single_byte_value_fifteen" {
  let bytes = [15]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0f")
}

test "hex_single_byte_value_255" {
  let bytes = [255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "ff")
}

test "hex_alternating_high_low" {
  let bytes = [255, 0, 255, 0]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "ff00ff00")
}

test "hex_all_bytes_0_to_15" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "000102030405060708090a0b0c0d0e0f")
}

test "hex_bytes_16_to_31" {
  let bytes = [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "101112131415161718191a1b1c1d1e1f")
}

test "hex_power_of_two_values" {
  let bytes = [1, 2, 4, 8, 16, 32, 64, 128]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0102040810204080")
}

test "hex_boundary_values" {
  let bytes = [0, 1, 127, 128, 254, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "00017f80feff")
}

test "span_context_zero_trace_flags_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 0)
  assert_false(context.is_sampled())
}

test "span_context_trace_flags_one_is_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_sampled())
}

test "span_context_trace_flags_three_is_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 3)
  assert_true(context.is_sampled())
}

test "span_context_trace_flags_two_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 2)
  assert_false(context.is_sampled())
}

test "span_context_trace_flags_four_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 4)
  assert_false(context.is_sampled())
}

test "span_context_trace_flags_254_is_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 254)
  assert_false(context.is_sampled())
}

test "span_context_trace_flags_255_is_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 255)
  assert_true(context.is_sampled())
}

test "span_context_preserves_trace_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let flags = 5
  let context = span_context(trace_id, span_id, flags)
  assert_eq(context.trace_flags, flags)
}

test "span_context_is_valid_with_non_zero_trace_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_context_is_valid_with_non_zero_span_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}
