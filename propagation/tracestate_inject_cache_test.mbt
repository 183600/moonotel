// The `tracestate` injection path caches parsed values to avoid reparsing the
// same header. The cache is bounded, so exercising more distinct values than
// its limit checks that eviction never changes the propagated header.

///|
fn cache_test_context(state : String) -> @api.SpanContext {
  let trace_id = @api.bytes_from_hex(
    "4bf92f359d1e75b7618a2d1f3c4e5a6b",
  ).unwrap()
  let span_id = @api.bytes_from_hex("00f067aa0ba902b7").unwrap()
  @api.span_context(trace_id, span_id, 1).with_tracestate(state)
}

///|
test "tracestate_injection_stays_correct_after_cache_eviction" {
  let mut index = 0
  while index < 160 {
    let state = "vendor" + index.to_string() + "=value" + index.to_string()
    let carrier = @propagation.TextMapCarrier::new()
    @propagation.inject(cache_test_context(state), carrier)
    assert_eq(carrier.get("tracestate"), Some(state))
    index = index + 1
  }
  // The first values have been evicted by now; normalizing them again must
  // still produce the same header.
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject(cache_test_context("vendor0=value0"), carrier)
  assert_eq(carrier.get("tracestate"), Some("vendor0=value0"))
}

///|
test "invalid_tracestate_is_still_dropped_after_cache_eviction" {
  let mut index = 0
  while index < 140 {
    // A blank inside the key is invalid, so the parsed value is cached as
    // invalid and must never be written back.
    let state = "bad" + index.to_string() + " key=value"
    let carrier = @propagation.TextMapCarrier::new()
    @propagation.inject(cache_test_context(state), carrier)
    assert_eq(carrier.get("tracestate"), None)
    assert_true(carrier.get("traceparent") is Some(_))
    index = index + 1
  }
}
