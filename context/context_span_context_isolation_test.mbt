// Tests that a Context owns its SpanContext rather than aliasing caller-held
// ID arrays or exposing them through accessors.

///|
fn isolation_span_context(trace_byte : Int32, span_byte : Int32) -> @api.SpanContext {
  @api.span_context(Array::make(16, trace_byte), Array::make(8, span_byte), 1)
}

///|
test "with_span_does_not_alias_the_caller_span_context" {
  let sc = isolation_span_context(1, 2)
  let trace_hex = sc.trace_id_hex()
  let span_hex = sc.span_id_hex()
  let context = @context.Context::root().with_span(sc)
  sc.trace_id_view()[0] = 99
  sc.span_id_view()[0] = 99
  let stored = context.span_context().unwrap()
  assert_eq(stored.trace_id_hex(), trace_hex)
  assert_eq(stored.span_id_hex(), span_hex)
}

///|
test "span_context_accessor_returns_an_independent_copy" {
  let sc = isolation_span_context(3, 4)
  let trace_hex = sc.trace_id_hex()
  let span_hex = sc.span_id_hex()
  let context = @context.Context::root().with_span(sc)
  let view = context.span_context().unwrap()
  view.trace_id_view()[0] = 99
  view.span_id_view()[0] = 99
  let stored = context.span_context().unwrap()
  assert_eq(stored.trace_id_hex(), trace_hex)
  assert_eq(stored.span_id_hex(), span_hex)
}
