// White-box regression test: the async HTTP client adds transport headers
// (`Host`) to the map it receives, so the exporter must hand it a copy instead
// of its cached header map.

///|
fn header_isolation_span() -> @sdk.SpanData {
  {
    name: "header-isolation",
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Client,
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
    resource: @sdk.ResourceAttributes::new(Map([])),
    scope_name: "header-isolation",
    scope_version: "",
  }
}

///|
async test "async exporter does not mutate its cached request headers" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        let _ = body.read_all()
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
    )
    let exporter = OtlpHttpAsyncExporter::new(config)
    let result = exporter.export_batch([header_isolation_span()])
    assert_true(result.is_success())
    assert_false(
      exporter.headers.contains(@http.CaseInsensitiveString("host")),
    )
    assert_eq(
      exporter.headers.get(
        @http.CaseInsensitiveString("content-type"),
      ),
      Some("application/x-protobuf"),
    )
  }
}
