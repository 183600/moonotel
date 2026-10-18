// Blackbox tests for request extraction through the process-wide propagator.

///|
fn server_global_propagator_parent() -> @api.SpanContext {
  @api.span_context(
    Array::make(16, 21),
    Array::make(8, 22),
    @api.TRACE_FLAGS_SAMPLED,
  )
}

///|
test "extract_context honors an installed global propagator" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  let none : &@propagation.TextMapPropagator = @propagation.CompositePropagator::new(
    [],
  )
  @propagation.set_global_propagator(none)
  let headers : Map[@http.CaseInsensitiveString, String] = Map([])
  headers.set(
    @http.CaseInsensitiveString("traceparent"),
    @propagation.format_traceparent(server_global_propagator_parent()),
  )
  headers.set(@http.CaseInsensitiveString("baggage"), "user.id=42")
  let context = @async_http_server.extract_context(headers)
  assert_true(context.span_context() is None)
  assert_false(context.has_baggage())
}

///|
test "extract_context can be limited to baggage" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  let baggage_only : &@propagation.TextMapPropagator = @propagation.BaggagePropagator::new()
  @propagation.set_global_propagator(baggage_only)
  let headers : Map[@http.CaseInsensitiveString, String] = Map([])
  headers.set(
    @http.CaseInsensitiveString("traceparent"),
    @propagation.format_traceparent(server_global_propagator_parent()),
  )
  headers.set(@http.CaseInsensitiveString("baggage"), "user.id=42")
  let context = @async_http_server.extract_context(headers)
  assert_true(context.span_context() is None)
  assert_eq(context.value("user.id"), Some("42"))
}
