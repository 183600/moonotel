// White-box tests for injecting headers through the process-wide propagator.
// These are synchronous so that they run before the package's async tests and
// cannot race them on the shared propagator.

///|
fn wbtest_span_context() -> @api.SpanContext {
  @api.span_context(
    [
      0x4b, 0xf9, 0x2f, 0x35, 0x9d, 0x1e, 0x75, 0xb7, 0x61, 0x8a, 0x2d, 0x1f, 0x3c,
      0x4e, 0x5a, 0x6b,
    ],
    [0x00, 0xf0, 0x67, 0xaa, 0x0b, 0xa9, 0x02, 0xb7],
    @api.TRACE_FLAGS_SAMPLED,
  )
}

///|
test "traced_headers injects the trace context and baggage by default" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  let defaults : &@propagation.TextMapPropagator = @propagation.CompositePropagator::new(
    [
      @propagation.TraceContextPropagator::new(),
      @propagation.BaggagePropagator::new(),
    ],
  )
  @propagation.set_global_propagator(defaults)
  let context = @context.Context::root().with_value("user.id", "42")
  let headers = traced_headers(None, wbtest_span_context(), context)
  assert_eq(
    headers.get(@http.CaseInsensitiveString("traceparent")),
    Some(@propagation.format_traceparent(wbtest_span_context())),
  )
  assert_eq(
    headers.get(@http.CaseInsensitiveString("baggage")),
    Some("user.id=42"),
  )
}

///|
test "traced_headers injects nothing when the global propagator is empty" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  let empty : &@propagation.TextMapPropagator = @propagation.CompositePropagator::new(
    [],
  )
  @propagation.set_global_propagator(empty)
  let context = @context.Context::root().with_value("user.id", "42")
  let headers = traced_headers(None, wbtest_span_context(), context)
  assert_eq(headers.length(), 0)
}

///|
test "traced_headers follows a baggage-only global propagator" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  let baggage_only : &@propagation.TextMapPropagator = @propagation.BaggagePropagator::new()
  @propagation.set_global_propagator(baggage_only)
  let context = @context.Context::root().with_value("user.id", "42")
  let headers = traced_headers(None, wbtest_span_context(), context)
  assert_eq(
    headers.get(@http.CaseInsensitiveString("baggage")),
    Some("user.id=42"),
  )
  assert_true(headers.get(@http.CaseInsensitiveString("traceparent")) is None)
}

///|
test "traced_headers keeps caller headers alongside the injected ones" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  let empty : &@propagation.TextMapPropagator = @propagation.CompositePropagator::new(
    [],
  )
  @propagation.set_global_propagator(empty)
  let caller : Map[String, String] = Map([("x-request-id", "abc")])
  let headers = traced_headers(
    Some(caller),
    wbtest_span_context(),
    @context.Context::root(),
  )
  assert_eq(headers.length(), 1)
  assert_eq(
    headers.get(@http.CaseInsensitiveString("x-request-id")),
    Some("abc"),
  )
}
