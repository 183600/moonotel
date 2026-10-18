// Blackbox tests for the HTTP semantic-convention attributes recorded by the
// server instrumentation.

///|
struct SemconvRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for SemconvRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for SemconvRecordingExporter with fn shutdown(self) {
  let _ = self
}

///|
async test "server records url.scheme and user_agent.original" {
  let exporter : SemconvRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(service_name="semconv-test").with_span_processor(
    processor,
  )
  let tracer = provider.get_tracer("semconv-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(200, body="ok"),
        tracer~,
      )
    }
    let (response, _body) = @http.get("http://127.0.0.1:\{port}/semconv", headers={
      "user-agent": "otel-semconv-test/1.0",
    })
    assert_eq(response.code, 200)
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.URL_SCHEME),
      Some(@sdk.StringValue("http")),
    )
    assert_eq(
      data.attributes.get(@sdk.USER_AGENT_ORIGINAL),
      Some(@sdk.StringValue("otel-semconv-test/1.0")),
    )
  }
}

///|
async test "server omits user_agent.original when the header is absent" {
  let exporter : SemconvRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(service_name="semconv-test").with_span_processor(
    processor,
  )
  let tracer = provider.get_tracer("semconv-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(204),
        tracer~,
      )
    }
    let connection_addr = @socket.Addr::parse("127.0.0.1:\{port}")
    let connection = @socket.Tcp::connect(connection_addr)
    connection.write(
      "GET /no-agent HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n",
    )
    let _ = connection.read_all()
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.attributes.get(@sdk.USER_AGENT_ORIGINAL), None)
  }
}
