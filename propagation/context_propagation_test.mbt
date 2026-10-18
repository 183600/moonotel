// Blackbox tests for context-level propagation helpers.

///|
fn context_propagation_span() -> @api.SpanContext {
  @api.span_context(
    [
      0x4b, 0xf9, 0x2f, 0x35, 0x9d, 0x1e, 0x75, 0xb7, 0x61, 0x8a, 0x2d, 0x1f, 0x3c,
      0x4e, 0x5a, 0x6b,
    ],
    [0x00, 0xf0, 0x67, 0xaa, 0x0b, 0xa9, 0x02, 0xb7],
    @api.TRACE_FLAGS_SAMPLED,
    tracestate="congo=t61rcWkgMzE",
  )
}

///|
test "inject_context writes trace context and baggage" {
  let context = @context.Context::root()
    .with_span(context_propagation_span())
    .with_value("user.id", "42")
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_context(context, carrier)
  assert_eq(
    carrier.get("traceparent"),
    Some("00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"),
  )
  assert_eq(carrier.get("tracestate"), Some("congo=t61rcWkgMzE"))
  assert_eq(carrier.get("baggage"), Some("user.id=42"))
}

///|
test "extract_context round_trips span and baggage" {
  let context = @context.Context::root()
    .with_span(context_propagation_span())
    .with_value("user.id", "42")
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_context(context, carrier)
  let extracted = @propagation.extract_context(carrier)
  let span = extracted.span_context().unwrap()
  assert_eq(span.trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
  assert_eq(span.span_id_hex(), "00f067aa0ba902b7")
  assert_eq(span.tracestate(), "congo=t61rcWkgMzE")
  assert_eq(extracted.value("user.id"), Some("42"))
  assert_true(extracted.has_baggage())
}

///|
test "extract_context without traceparent keeps baggage" {
  let carrier = @propagation.TextMapCarrier::from_entries([
    ("baggage", "user.id=42,tenant=acme"),
  ])
  let context = @propagation.extract_context(carrier)
  assert_true(context.span_context() is None)
  assert_eq(context.value("user.id"), Some("42"))
  assert_eq(context.value("tenant"), Some("acme"))
}

///|
test "extract_context without baggage keeps the trace context" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject(context_propagation_span(), carrier)
  let context = @propagation.extract_context(carrier)
  assert_true(context.span_context().unwrap().is_sampled())
  assert_false(context.has_baggage())
}

///|
test "extract_context returns the root context for an empty carrier" {
  let context = @propagation.extract_context(@propagation.TextMapCarrier::new())
  assert_true(context.span_context() is None)
  assert_false(context.has_baggage())
}

///|
test "extract_context ignores an invalid traceparent but keeps baggage" {
  let carrier = @propagation.TextMapCarrier::from_entries([
    ("traceparent", "00-00000000000000000000000000000000-0000000000000000-01"),
    ("baggage", "user.id=42"),
  ])
  let context = @propagation.extract_context(carrier)
  assert_true(context.span_context() is None)
  assert_eq(context.value("user.id"), Some("42"))
}

///|
test "inject_context without a span writes only baggage" {
  let context = @context.Context::root().with_value("user.id", "42")
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_context(context, carrier)
  assert_true(carrier.get("traceparent") is None)
  assert_eq(carrier.get("baggage"), Some("user.id=42"))
}

///|
test "inject_context with an invalid span writes only baggage" {
  let context = @context.Context::root()
    .with_span(@api.invalid_span_context())
    .with_value("user.id", "42")
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_context(context, carrier)
  assert_true(carrier.get("traceparent") is None)
  assert_eq(carrier.get("baggage"), Some("user.id=42"))
}
