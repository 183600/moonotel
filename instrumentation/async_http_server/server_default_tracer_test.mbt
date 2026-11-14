// The server instrumentation must use the process-wide tracer provider when
// the caller does not pass a tracer explicitly.

///|
struct DefaultTracerRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for DefaultTracerRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for DefaultTracerRecordingExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
async test "run_server_on uses the global tracer provider by default" {
  @sdk.shutdown_global_tracer_provider()
  defer @sdk.shutdown_global_tracer_provider()
  let exporter : DefaultTracerRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="default-server-tracer",
  ).with_span_processor(processor)
  @sdk.set_global_tracer_provider(provider)
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        call.respond(200, body="ok")
      })
    }
    let (response, body) = @http.get(
      "http://127.0.0.1:\{port}/default-tracer",
    )
    assert_eq(response.code, 200)
    assert_eq(body.text(), "ok")
    @async.sleep(50)
    // Other tests in this package may also be running against the global
    // provider concurrently, so select the span for this request instead of
    // assuming the exporter only saw one span.
    let mut matched : @sdk.SpanData? = None
    for data in exporter.spans.val {
      if data.attributes.get(@sdk.URL_PATH) ==
        Some(@sdk.StringValue("/default-tracer")) {
        matched = Some(data)
      }
    }
    let data = matched.unwrap()
    assert_eq(data.name, "GET")
    assert_eq(data.kind, @api.SpanKind::Server)
    assert_eq(
      data.attributes.get(@sdk.URL_PATH),
      Some(@sdk.StringValue("/default-tracer")),
    )
    assert_eq(
      data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE),
      Some(@sdk.IntValue(200)),
    )
  }
}
