// Validation and corner case tests

// Tests for trace ID with single non-zero byte at each position
test "trace_id_nonzero_at_pos_0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_1" {
  let trace_id = [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_2" {
  let trace_id = [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_3" {
  let trace_id = [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_4" {
  let trace_id = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_5" {
  let trace_id = [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_6" {
  let trace_id = [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_7" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_8" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_9" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_10" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_11" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_12" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_13" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_14" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "trace_id_nonzero_at_pos_15" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

// Tests for span ID with single non-zero byte at each position
test "span_id_nonzero_at_pos_0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_nonzero_at_pos_1" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 1, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_nonzero_at_pos_2" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 1, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_nonzero_at_pos_3" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 1, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_nonzero_at_pos_4" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 1, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_nonzero_at_pos_5" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 1, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_nonzero_at_pos_6" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 1, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_id_nonzero_at_pos_7" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

// Tests for hex encoding with single bytes
test "hex_single_byte_00" {
  let bytes = [0]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "00")
}

test "hex_single_byte_0f" {
  let bytes = [15]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0f")
}

test "hex_single_byte_10" {
  let bytes = [16]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "10")
}

test "hex_single_byte_1f" {
  let bytes = [31]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "1f")
}

test "hex_single_byte_20" {
  let bytes = [32]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "20")
}

test "hex_single_byte_7f" {
  let bytes = [127]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "7f")
}

test "hex_single_byte_80" {
  let bytes = [128]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "80")
}

test "hex_single_byte_fe" {
  let bytes = [254]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "fe")
}

test "hex_single_byte_ff" {
  let bytes = [255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "ff")
}

// Tests for various sampling flags
test "sampling_flag_11" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 11)
  assert_true(context.is_sampled())
}

test "sampling_flag_13" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 13)
  assert_true(context.is_sampled())
}

test "sampling_flag_17" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 17)
  assert_true(context.is_sampled())
}

test "sampling_flag_19" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 19)
  assert_true(context.is_sampled())
}

test "sampling_flag_21" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 21)
  assert_true(context.is_sampled())
}

test "sampling_flag_32" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 32)
  assert_false(context.is_sampled())
}

test "sampling_flag_96" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 96)
  assert_false(context.is_sampled())
}

test "sampling_flag_160" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 160)
  assert_false(context.is_sampled())
}

test "sampling_flag_192" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 192)
  assert_false(context.is_sampled())
}

// Tests for context with specific patterns
test "context_with_fibonacci_sequence" {
  let trace_id = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 121, 98, 219]
  let span_id = [1, 1, 2, 3, 5, 8, 13, 21]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "context_with_powers_of_two" {
  let trace_id = [1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128]
  let span_id = [1, 2, 4, 8, 16, 32, 64, 128]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "context_with_multiples_of_ten" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [10, 20, 30, 40, 50, 60, 70, 80]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

// Tests for hex encoding of two-byte patterns
test "hex_two_bytes_0001" {
  let bytes = [0, 1]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0001")
}

test "hex_two_bytes_0102" {
  let bytes = [1, 2]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "0102")
}

test "hex_two_bytes_fffe" {
  let bytes = [255, 254]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "fffe")
}

test "hex_two_bytes_ffff" {
  let bytes = [255, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "ffff")
}
