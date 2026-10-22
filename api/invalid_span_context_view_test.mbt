// The shared invalid SpanContext must not let mutation through one ID view
// leak into a later view of the singleton.

///|
test "invalid_span_context_views_are_independent" {
  let first = @api.invalid_span_context()
  let trace_view = first.trace_id_view()
  let span_view = first.span_id_view()
  trace_view[0] = 99
  span_view[0] = 99
  trace_view.clear()
  span_view.clear()

  let second = @api.invalid_span_context()
  let second_trace = second.trace_id_view()
  let second_span = second.span_id_view()
  assert_eq(second_trace.length(), 16)
  assert_eq(second_span.length(), 8)
  assert_eq(second_trace[0], 0)
  assert_eq(second_span[0], 0)
  assert_eq(
    second.trace_id_hex(),
    "00000000000000000000000000000000",
  )
  assert_eq(second.span_id_hex(), "0000000000000000")
  assert_false(second.is_valid())
}

///|
test "invalid_span_context_views_do_not_alias_their_calls" {
  let invalid = @api.invalid_span_context()
  let trace_view = invalid.trace_id_view()
  trace_view[1] = 7
  // A second call returns a distinct zero-filled array.
  assert_eq(invalid.trace_id_view()[1], 0)
  trace_view[1] = 0
  assert_eq(invalid.trace_id_view()[1], 0)
}

///|
test "validity_requires_the_live_id_array_lengths" {
  let sc = @api.span_context(Array::make(16, 1), Array::make(8, 1), 1)
  assert_true(sc.is_valid())
  sc.trace_id_view().clear()
  assert_false(sc.is_valid())
  sc.trace_id_view().push(1)
  assert_false(sc.is_valid())
  assert_eq(sc.trace_id_view().length(), 1)

  let grown = @api.span_context(Array::make(16, 1), Array::make(8, 1), 1)
  grown.span_id_view().push(1)
  assert_false(grown.is_valid())
}
