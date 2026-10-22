// A reused carrier may hold a header under a different spelling. Injection
// must replace it case-insensitively instead of adding a second header that
// would be sent alongside the new one.

///|
fn injection_case_test_context() -> @api.SpanContext {
  @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
    tracestate="vendor=new",
  )
}

///|
test "inject_replaces_differently_cased_trace_headers" {
  let context = injection_case_test_context()
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("TraceParent", "00-stale")
  carrier.set("TraceState", "stale=value")
  @propagation.inject(context, carrier)
  assert_eq(carrier.length(), 2)
  assert_eq(
    carrier.get("TraceParent"),
    Some(@propagation.format_traceparent(context)),
  )
  assert_eq(carrier.get("TraceState"), Some("vendor=new"))
}

///|
test "inject_with_tracestate_replaces_differently_cased_trace_headers" {
  let context = injection_case_test_context()
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("TraceParent", "00-stale")
  @propagation.inject_with_tracestate(context, Some("override=1"), carrier)
  assert_eq(carrier.length(), 2)
  assert_eq(
    carrier.get("TraceParent"),
    Some(@propagation.format_traceparent(context)),
  )
  assert_eq(carrier.get("TraceState"), Some("override=1"))
}

///|
test "inject_baggage_replaces_a_differently_cased_header" {
  let context = @context.Context::root().with_value("new", "2")
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("Baggage", "stale=1")
  @propagation.inject_baggage(context, carrier)
  assert_eq(carrier.length(), 1)
  assert_eq(carrier.get("Baggage"), Some("new=2"))
}

///|
test "inject_baggage_entries_replaces_a_differently_cased_header" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("Baggage", "stale=1")
  @propagation.inject_baggage_entries(
    [@propagation.BaggageEntry::new("new", "2")],
    carrier,
  )
  assert_eq(carrier.length(), 1)
  assert_eq(carrier.get("Baggage"), Some("new=2"))
}
