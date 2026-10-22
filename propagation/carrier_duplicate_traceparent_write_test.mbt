// A single `set` must make a duplicated `traceparent` field unambiguous again,
// even when `from_entries` combined the repeated values under a differently
// cased spelling.

///|
fn carrier_write_span_context() -> @api.SpanContext {
  @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    1,
    is_remote=true,
  )
}

///|
test "from_entries_duplicate_traceparent_clears_after_a_mixed_case_write" {
  let carrier = @propagation.TextMapCarrier::from_entries([
    ("traceparent", "01-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01-"),
    ("TraceParent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"),
  ])
  let sc = carrier_write_span_context()
  carrier.set("TRACEPARENT", @propagation.format_traceparent(sc))
  assert_eq(carrier.get_all("traceparent").length(), 1)
  let extracted = @propagation.extract(carrier).unwrap()
  assert_eq(extracted.trace_id_hex(), sc.trace_id_hex())
  assert_eq(extracted.span_id_hex(), sc.span_id_hex())
}
