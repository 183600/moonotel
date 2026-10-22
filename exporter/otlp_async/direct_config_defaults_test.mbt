// A directly built `OtlpHttpConfig` with blank protocol/compression values
// must use the same defaults as `OtlpHttpConfig::new`: `http/protobuf` with no
// compression, announced consistently in the request headers.

///|
fn blank_config_span_data() -> @sdk.SpanData {
  let span_context = @api.span_context(
    Array::make(16, 7),
    Array::make(8, 9),
    @api.TRACE_FLAGS_SAMPLED,
  )
  {
    name: "otlp-async-blank-config",
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
    scope_name: "otlp-async-blank-config-test",
    scope_version: "",
  }
}

///|
async test "blank direct protocol and compression use the OTLP defaults" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let content_type : Ref[String] = Ref("")
    let encoding : Ref[String] = Ref("<absent>")
    let requests : Ref[Int32] = Ref(0)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        requests.val = requests.val + 1
        content_type.val = request.headers
          .get(@http.CaseInsensitiveString("content-type"))
          .unwrap_or("")
        encoding.val = request.headers
          .get(@http.CaseInsensitiveString("content-encoding"))
          .unwrap_or("<absent>")
        conn.send_response(200, "OK")
      })
    }
    let config : @otlp.OtlpHttpConfig = {
      endpoint: "http://127.0.0.1:\{port}",
      traces_endpoint: None,
      headers: Map([]),
      timeout_millis: 10000,
      compression: " \t ",
      protocol: " ",
      max_retries: 0,
    }
    let result = @otlp_async.export_spans(config, [
      blank_config_span_data(),
    ])
    assert_true(result.is_success())
    assert_eq(requests.val, 1)
    assert_eq(content_type.val, "application/x-protobuf")
    assert_eq(encoding.val, "<absent>")
  }
}

///|
async test "blank direct config is also accepted by the async exporter object" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let requests : Ref[Int32] = Ref(0)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        requests.val = requests.val + 1
        conn.send_response(200, "OK")
      })
    }
    let config : @otlp.OtlpHttpConfig = {
      endpoint: "http://127.0.0.1:\{port}",
      traces_endpoint: None,
      headers: Map([]),
      timeout_millis: 10000,
      compression: "",
      protocol: "",
      max_retries: 0,
    }
    let exporter = @otlp_async.OtlpHttpAsyncExporter::new(config)
    let result = exporter.export_batch([blank_config_span_data()])
    assert_true(result.is_success())
    assert_eq(requests.val, 1)
  }
}
