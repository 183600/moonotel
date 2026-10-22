// Validity agrees with the byte serialization: IDs whose low eight bits are
// all zero cannot be represented in hex, traceparent or OTLP, so they are not
// valid even when the raw Int32 elements are nonzero.

///|
test "span_context_with_serially_zero_ids_is_invalid" {
  let trace_id = Array::make(16, 0)
  trace_id[0] = 256
  let span_id = Array::make(8, 0)
  span_id[0] = 1
  let sc = @api.span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")

  let trace_id = Array::make(16, 1)
  let span_id = Array::make(8, 0)
  span_id[7] = 256
  let sc = @api.span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0000000000000000")
}

///|
test "span_context_uses_the_low_byte_for_validity" {
  let trace_id = Array::make(16, 0)
  trace_id[0] = 256
  trace_id[1] = 1
  let span_id = Array::make(8, 0)
  span_id[7] = 255
  let sc = @api.span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00010000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "00000000000000ff")
}
