// An explicit `tracestate` argument to `inject_with_tracestate` overrides the
// state carried by the SpanContext, including an empty value that suppresses
// the header entirely.

///|
fn override_context() -> @api.SpanContext {
  @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    1,
    tracestate="congo=t61rcWkgMzE",
  )
}

///|
test "explicit_empty_tracestate_suppresses_the_context_state" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_with_tracestate(
    override_context(), Some(""), carrier,
  )
  assert_true(carrier.get(@propagation.traceparent_header_name()) is Some(_))
  assert_eq(@propagation.extract_tracestate(carrier), None)
}

///|
test "explicit_tracestate_replaces_the_context_state" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_with_tracestate(
    override_context(), Some("vendor=value"), carrier,
  )
  assert_eq(@propagation.extract_tracestate(carrier), Some("vendor=value"))
}

///|
test "invalid_explicit_tracestate_drops_even_the_context_state" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_with_tracestate(
    override_context(), Some("not a valid state"), carrier,
  )
  assert_true(carrier.get(@propagation.traceparent_header_name()) is Some(_))
  assert_eq(@propagation.extract_tracestate(carrier), None)
}

///|
test "explicit_empty_tracestate_removes_a_previously_written_header" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    @propagation.tracestate_header_name(),
    "stale=value",
  )
  @propagation.inject_with_tracestate(
    override_context(), Some(""), carrier,
  )
  assert_eq(@propagation.extract_tracestate(carrier), None)
}

///|
test "omitted_tracestate_keeps_the_context_state" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_with_tracestate(override_context(), None, carrier)
  assert_eq(
    @propagation.extract_tracestate(carrier),
    Some("congo=t61rcWkgMzE"),
  )
}
