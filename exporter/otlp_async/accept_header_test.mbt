// The async OTLP/HTTP exporter announces the response format it accepts, as
// the OTLP/HTTP specification asks the client to do.

///|
fn accept_test_span_data() -> @sdk.SpanData {
  let trace_id = Array::make(16, 7)
  let span_id = Array::make(8, 9)
  let span_context = @api.span_context(
    trace_id,
    span_id,
    @api.TRACE_FLAGS_SAMPLED,
  )
  {
    name: "otlp-async-accept-op",
    span_context,
    parent_span_id: [],
    kind: @api.SpanKind::Client,
    start_time_unix_nano: 1000L,
    end_time_unix_nano: 2000L,
    attributes: Map([]),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(Map([])),
    scope_name: "otlp-async-accept-test",
    scope_version: "",
  }
}

///|
async test "request headers announce the accepted format" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let observed : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        observed.val = request.headers
          .get(@http.CaseInsensitiveString("accept"))
          .unwrap_or("")
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    let result = @otlp_async.export_spans(config, [accept_test_span_data()])
    assert_true(result.is_success())
    assert_eq(observed.val, "application/x-protobuf")
  }
}

///|
async test "request headers announce the accepted json format" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let observed : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        observed.val = request.headers
          .get(@http.CaseInsensitiveString("accept"))
          .unwrap_or("")
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      protocol=@otlp.OTLP_HTTP_JSON_PROTOCOL,
    )
    let result = @otlp_async.export_spans(config, [accept_test_span_data()])
    assert_true(result.is_success())
    assert_eq(observed.val, "application/json")
  }
}
