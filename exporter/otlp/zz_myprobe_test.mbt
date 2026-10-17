///|
test "zz_myprobe_encode_public" (b : @bench.T) {
  let span_context = @api.span_context(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    [1, 2, 3, 4, 5, 6, 7, 8],
    1,
  )
  let span : @sdk.SpanData = {
    name: "GET /path",
    span_context,
    parent_span_id: [],
    kind: @api.SpanKind::Server,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map([]),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: Map([]),
    scope_name: "bench",
    scope_version: "",
  }
  b.bench(fn() {
    let _ = encode_trace_request([span])
  })
}
