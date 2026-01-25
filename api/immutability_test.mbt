// Regression tests for SpanContext mutation/aliasing behavior

test "span_context_aliases_input_arrays" {
  let trace_id = Array::make(16, 0)
  trace_id[0] = 1

  let span_id = Array::make(8, 0)
  span_id[0] = 2

  let sc = span_context(trace_id, span_id, 1)

  trace_id[0] = 9
  span_id[0] = 9

  assert_eq(sc.trace_id[0], 9)
  assert_eq(sc.span_id[0], 9)
}

test "span_context_validity_does_not_recompute_after_id_mutation" {
  let trace_id = Array::make(16, 0)
  trace_id[15] = 1

  let span_id = Array::make(8, 0)
  span_id[7] = 1

  let sc = span_context(trace_id, span_id, 0)

  trace_id[15] = 0
  span_id[7] = 0

  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
}
