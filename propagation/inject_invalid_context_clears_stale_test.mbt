// Reusing a carrier must not leak trace headers from an earlier injection when
// the context passed to the next injection has no valid span. Baggage belongs
// to a different propagator and must be left untouched.

///|
fn stale_injection_carrier() -> @propagation.TextMapCarrier {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    "traceparent",
    "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01",
  )
  carrier.set("tracestate", "vendor=value")
  carrier.set("baggage", "user.id=42")
  carrier
}

///|
test "inject with an invalid context clears stale trace headers" {
  let carrier = stale_injection_carrier()
  @propagation.inject(@api.invalid_span_context(), carrier)
  assert_true(carrier.get("traceparent") is None)
  assert_true(carrier.get("tracestate") is None)
  assert_eq(carrier.get("baggage"), Some("user.id=42"))
}

///|
test "inject_with_tracestate with an invalid context clears stale trace headers" {
  let carrier = stale_injection_carrier()
  @propagation.inject_with_tracestate(
    @api.invalid_span_context(), Some("vendor=override"), carrier,
  )
  assert_true(carrier.get("traceparent") is None)
  assert_true(carrier.get("tracestate") is None)
  assert_eq(carrier.get("baggage"), Some("user.id=42"))
}
