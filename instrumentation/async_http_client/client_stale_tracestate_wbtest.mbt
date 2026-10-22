// The client injects through a write-through header carrier. A stale
// `tracestate` supplied by the caller must not survive when the new span's
// context carries no state.

///|
test "traced_headers clears a caller-supplied stale tracestate" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  let defaults : &@propagation.TextMapPropagator = @propagation.CompositePropagator::new(
    [
      @propagation.TraceContextPropagator::new(),
      @propagation.BaggagePropagator::new(),
    ],
  )
  @propagation.set_global_propagator(defaults)
  let sc = @api.span_context(
    [
      0x4b, 0xf9, 0x2f, 0x35, 0x9d, 0x1e, 0x75, 0xb7, 0x61, 0x8a, 0x2d, 0x1f,
      0x3c, 0x4e, 0x5a, 0x6b,
    ],
    [0x00, 0xf0, 0x67, 0xaa, 0x0b, 0xa9, 0x02, 0xb7],
    @api.TRACE_FLAGS_SAMPLED,
  )
  let caller : Map[String, String] = Map([
    ("tracestate", "stale=value"),
    ("x-request-id", "abc"),
  ])
  let headers = traced_headers(Some(caller), sc, @context.Context::root())
  assert_eq(
    headers.get(@http.CaseInsensitiveString("traceparent")),
    Some(@propagation.format_traceparent(sc)),
  )
  assert_true(
    headers.get(@http.CaseInsensitiveString("tracestate")) is None,
  )
  assert_eq(
    headers.get(@http.CaseInsensitiveString("x-request-id")),
    Some("abc"),
  )
}
