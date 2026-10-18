// Tests for `SpanContext::is_remote`, which marks contexts received from a
// remote parent through a propagator.

///|
test "span_context defaults to local" {
  let sc = @api.span_context(Array::make(16, 1), Array::make(8, 2), 0)
  assert_false(sc.is_remote())
}

///|
test "span_context can be created as remote" {
  let sc = @api.span_context(
    Array::make(16, 1),
    Array::make(8, 2),
    0,
    is_remote=true,
  )
  assert_true(sc.is_remote())
}

///|
test "with_remote overrides the flag" {
  let sc = @api.span_context(Array::make(16, 1), Array::make(8, 2), 0)
  assert_true(sc.with_remote(true).is_remote())
  assert_false(sc.with_remote(true).with_remote(false).is_remote())
}

///|
test "with_tracestate preserves the remote flag" {
  let sc = @api.span_context(
    Array::make(16, 1),
    Array::make(8, 2),
    0,
    is_remote=true,
  )
  let sc = sc.with_tracestate("a=1")
  assert_true(sc.is_remote())
  assert_eq(sc.tracestate(), "a=1")
}

///|
test "invalid context is not remote" {
  assert_false(@api.invalid_span_context().is_remote())
}
