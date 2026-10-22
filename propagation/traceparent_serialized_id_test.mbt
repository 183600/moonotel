// `format_traceparent` serializes an ID array the same way `bytes_to_hex`
// does, including out-of-range elements: only the low nibble contributes to
// the wire byte. This exercises the canonicalization path rather than the
// common all-in-range fast path.

///|
test "format_traceparent_canonicalizes_out_of_range_id_bytes" {
  let trace_id = Array::make(16, 0)
  trace_id[0] = 0x101
  trace_id[15] = -2
  let span_id = Array::make(8, 0)
  span_id[0] = 0x1FF
  let sc = @api.span_context(trace_id, span_id, 0x06)
  assert_true(sc.is_valid())

  let canonical_trace = Array::make(16, 0)
  canonical_trace[0] = 1
  canonical_trace[15] = 14
  let canonical_span = Array::make(8, 0)
  canonical_span[0] = 15
  let expected = "00-" +
    @api.bytes_to_hex(canonical_trace) +
    "-" +
    @api.bytes_to_hex(canonical_span) +
    "-02"
  assert_eq(@propagation.format_traceparent(sc), expected)
  assert_eq(sc.trace_id_hex(), @api.bytes_to_hex(canonical_trace))
  assert_eq(sc.span_id_hex(), @api.bytes_to_hex(canonical_span))

  let parsed = @propagation.parse_traceparent(expected).unwrap()
  assert_eq(parsed.trace_id_hex(), @api.bytes_to_hex(canonical_trace))
  assert_eq(parsed.span_id_hex(), @api.bytes_to_hex(canonical_span))
  assert_eq(parsed.trace_flags(), @api.TRACE_FLAGS_RANDOM)
}

///|
test "format_traceparent_rejects_ids_whose_bytes_canonicalize_to_zero" {
  let trace_id = Array::make(16, 0)
  trace_id[0] = 0x100
  let span_id = Array::make(8, 1)
  let sc = @api.span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
  assert_eq(@propagation.format_traceparent(sc), "")
}
