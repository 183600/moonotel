// A repeated `traceparent` is ambiguous even when the first value is a
// future-version header: its extension must not swallow the comma and the
// second field.

///|
let future_traceparent : String = "01-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01-"

///|
let version_00_traceparent : String = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"

///|
test "from_entries_duplicate_future_traceparent_restarts" {
  let carrier = @propagation.TextMapCarrier::from_entries([
    ("traceparent", future_traceparent),
    ("TraceParent", version_00_traceparent),
  ])
  assert_true(@propagation.extract(carrier) is None)
}

///|
test "from_entries_duplicate_traceparent_clears_after_a_single_write" {
  let carrier = @propagation.TextMapCarrier::from_entries([
    ("traceparent", future_traceparent),
    ("traceparent", version_00_traceparent),
  ])
  let sc = @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    1,
    is_remote=true,
  )
  @propagation.inject(sc, carrier)
  let extracted = @propagation.extract(carrier).unwrap()
  assert_eq(extracted.trace_id_hex(), sc.trace_id_hex())
  assert_eq(extracted.span_id_hex(), sc.span_id_hex())
}

///|
test "single_future_traceparent_still_extracts" {
  let carrier = @propagation.TextMapCarrier::from_entries([
    ("traceparent", future_traceparent),
  ])
  let extracted = @propagation.extract(carrier).unwrap()
  assert_eq(extracted.span_id_hex(), "00f067aa0ba902b7")
}
