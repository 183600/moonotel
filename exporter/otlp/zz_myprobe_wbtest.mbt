///|
test "zz_myprobe_encode_wb" (b : @bench.T) {
  let resource : Map[String, @sdk.AttributeValue] = Map([
    ("service.name", StringValue("svc")),
    ("telemetry.sdk.name", StringValue("opentelemetry")),
  ])
  let attributes : Map[String, @sdk.AttributeValue] = Map([
    ("http.request.method", StringValue("GET")),
    ("url.full", StringValue("http://example.com/path?q=1")),
    ("server.address", StringValue("example.com")),
    ("server.port", IntValue(80L)),
    ("http.response.status_code", IntValue(200L)),
  ])
  let events : Array[@sdk.SpanEvent] = [
    { name: "event1", time_unix_nano: 1L, attributes: Map([]), dropped_attributes_count: 0 },
    { name: "event2", time_unix_nano: 2L, attributes: Map([]), dropped_attributes_count: 0 },
  ]
  let span_context = @api.span_context(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    [1, 2, 3, 4, 5, 6, 7, 8],
    1,
  )
  let full : @sdk.SpanData = {
    name: "GET /path",
    span_context,
    parent_span_id: [],
    kind: @api.SpanKind::Server,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes,
    events,
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource,
    scope_name: "bench",
    scope_version: "1.0.0",
  }
  let bare : @sdk.SpanData = {
    ..full,
    attributes: Map([]),
    events: [],
  }
  b.bench(fn() {
    let w = ProtoWriter::with_capacity(448)
    let _ = w.to_bytes()
  })
  b.bench(fn() {
    let _ = group_spans([bare])
  })
  b.bench(fn() {
    let _ = group_spans([full])
  })
  b.bench(fn() {
    let w = ProtoWriter::with_capacity(448)
    let span = w.take_scratch()
    encode_span(span, bare)
    w.append_message(2, span)
    let _ = w.to_bytes()
  })
  b.bench(fn() {
    let w = ProtoWriter::with_capacity(448)
    let span = w.take_scratch()
    encode_span(span, full)
    w.append_message(2, span)
    let _ = w.to_bytes()
  })
  b.bench(fn() {
    let _ = encode_trace_request([bare])
  })
  b.bench(fn() {
    let _ = encode_trace_request([full])
  })
}
