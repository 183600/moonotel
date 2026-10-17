// Probe: encoded size of the bulk span set used by the benches.

///|
test "zz_myprobe_size_wb" {
  let trace_id = @api.span_context(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    [1, 2, 3, 4, 5, 6, 7, 8],
    1,
  )
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
  let spans : Array[@sdk.SpanData] = []
  let mut i = 0
  while i < 64 {
    spans.push({
      name: "GET /path",
      span_context: trace_id,
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
    })
    i = i + 1
  }
  let encoded = encode_trace_request(spans)
  inspect(encoded.length() / 64, content="266")
  let single = encode_trace_request([spans[0]])
  inspect(single.length(), content="351")
}
