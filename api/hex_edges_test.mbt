// Hex helpers handle out-of-range bytes defensively.

test "bytes_to_hex_masks_out_of_range_bytes" {
  assert_eq(@api.bytes_to_hex([999, -1]), "070f")
  assert_eq(@api.bytes_to_hex([999, 1]), "0701")
  assert_eq(@api.bytes_to_hex([1, 999]), "0107")
}

test "bytes_to_hex_masks_out_of_range_odd_length" {
  assert_eq(@api.bytes_to_hex([999]), "07")
  assert_eq(@api.bytes_to_hex([-1]), "0f")
}

test "bytes_from_hex_rejects_odd_length" {
  assert_true(@api.bytes_from_hex("abc") is None)
  assert_true(@api.bytes_from_hex("") is Some([]))
}

test "bytes_from_hex_rejects_non_ascii_characters" {
  assert_true(@api.bytes_from_hex("éé") is None)
}

test "bytes_from_hex_accepts_upper_and_mixed_case" {
  assert_eq(@api.bytes_from_hex("aB"), Some([0xab]))
}

test "span_context_from_hex_round_trips_valid_ids" {
  let trace_hex = "4bf92f359d1e75b7618a2d1f3c4e5a6b"
  let span_hex = "00f067aa0ba902b7"
  let sc = @api.span_context_from_hex(
    trace_hex, span_hex, @api.TRACE_FLAGS_SAMPLED,
  )
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
  assert_eq(sc.trace_flags(), @api.TRACE_FLAGS_SAMPLED)
  assert_eq(sc.trace_id_hex(), trace_hex)
  assert_eq(sc.span_id_hex(), span_hex)
}

test "span_context_from_hex_normalizes_uppercase" {
  let sc = @api.span_context_from_hex(
    "4BF92F359D1E75B7618A2D1F3C4E5A6B", "00F067AA0BA902B7", 0,
  )
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
  assert_eq(sc.span_id_hex(), "00f067aa0ba902b7")
}

test "span_context_from_hex_rejects_wrong_lengths" {
  assert_false(
    @api.span_context_from_hex("abcd", "00f067aa0ba902b7", 1).is_valid(),
  )
  assert_false(
    @api.span_context_from_hex(
      "4bf92f359d1e75b7618a2d1f3c4e5a6b", "1234", 1,
    ).is_valid(),
  )
}

test "span_context_from_hex_rejects_invalid_characters" {
  assert_false(
    @api.span_context_from_hex(
      "4bf92f359d1e75b7618a2d1f3c4e5ax", "00f067aa0ba902b7", 1,
    ).is_valid(),
  )
  assert_false(
    @api.span_context_from_hex(
      "4bf92f359d1e75b7618a2d1f3c4e5a6b", "00f067aa0ba902g7", 1,
    ).is_valid(),
  )
}

test "span_context_from_hex_rejects_zero_ids" {
  assert_false(
    @api.span_context_from_hex(
      "00000000000000000000000000000000",
      "00f067aa0ba902b7",
      @api.TRACE_FLAGS_SAMPLED,
    ).is_valid(),
  )
  assert_false(
    @api.span_context_from_hex(
      "4bf92f359d1e75b7618a2d1f3c4e5a6b",
      "0000000000000000",
      @api.TRACE_FLAGS_SAMPLED,
    ).is_valid(),
  )
}
