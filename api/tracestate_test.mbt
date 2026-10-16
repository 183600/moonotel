// Tests for the `tracestate` carried by a SpanContext.

fn tracestate_trace_id() -> Array[Int] {
  [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
}

fn tracestate_span_id() -> Array[Int] {
  [1, 2, 3, 4, 5, 6, 7, 8]
}

test "span_context_carries_tracestate" {
  let sc = span_context(
    tracestate_trace_id(),
    tracestate_span_id(),
    1,
    tracestate="vendor=value",
  )
  assert_true(sc.is_valid())
  assert_eq(sc.tracestate(), "vendor=value")
}

test "span_context_default_tracestate_is_empty" {
  let sc = span_context(tracestate_trace_id(), tracestate_span_id(), 1)
  assert_eq(sc.tracestate(), "")
  assert_eq(invalid_span_context().tracestate(), "")
}

test "with_tracestate_returns_a_copy" {
  let sc = span_context(tracestate_trace_id(), tracestate_span_id(), 1)
  let updated = sc.with_tracestate("other=state")
  assert_eq(updated.tracestate(), "other=state")
  assert_eq(sc.tracestate(), "")
  assert_eq(updated.trace_id_hex(), sc.trace_id_hex())
  assert_eq(updated.span_id_hex(), sc.span_id_hex())
  assert_eq(updated.trace_flags(), sc.trace_flags())
  assert_true(updated.is_valid())
}
