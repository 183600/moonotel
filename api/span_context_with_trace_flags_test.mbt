// Tests for `SpanContext::with_trace_flags`, which derives a copy with new
// raw trace flags while preserving IDs, tracestate, validity, and remoteness.

///|
test "with_trace_flags preserves the rest of a remote context" {
  let sc = @api.span_context(
    Array::make(16, 1),
    Array::make(8, 2),
    @api.TRACE_FLAGS_SAMPLED,
    tracestate="vendor=value",
    is_remote=true,
  )
  let updated = sc.with_trace_flags(
    @api.TRACE_FLAGS_SAMPLED | @api.TRACE_FLAGS_RANDOM,
  )
  assert_eq(updated.trace_flags(), 3)
  assert_true(updated.is_sampled())
  assert_true(updated.is_valid())
  assert_true(updated.is_remote())
  assert_eq(updated.tracestate(), "vendor=value")
  assert_eq(updated.trace_id(), Array::make(16, 1))
  assert_eq(updated.span_id(), Array::make(8, 2))
}

///|
test "with_trace_flags can clear the sampled flag" {
  let sc = @api.span_context(
    Array::make(16, 1),
    Array::make(8, 2),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let updated = sc.with_trace_flags(0)
  assert_eq(updated.trace_flags(), 0)
  assert_false(updated.is_sampled())
  assert_true(updated.is_valid())
}

///|
test "with_trace_flags leaves an invalid context invalid" {
  let sc = @api.span_context(
    Array::make(16, 0),
    Array::make(8, 2),
    @api.TRACE_FLAGS_SAMPLED,
    is_remote=true,
  )
  let updated = sc.with_trace_flags(@api.TRACE_FLAGS_RANDOM)
  assert_eq(updated.trace_flags(), @api.TRACE_FLAGS_RANDOM)
  assert_false(updated.is_valid())
  assert_false(updated.is_remote())
}

///|
test "with_trace_flags copies the ID arrays" {
  let trace_id = Array::make(16, 1)
  let span_id = Array::make(8, 2)
  let sc = @api.span_context(trace_id, span_id, 0)
  let updated = sc.with_trace_flags(@api.TRACE_FLAGS_SAMPLED)
  trace_id[0] = 99
  span_id[0] = 99
  assert_eq(updated.trace_id(), Array::make(16, 1))
  assert_eq(updated.span_id(), Array::make(8, 2))
  assert_true(updated.is_sampled())
}
