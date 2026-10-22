// The HTTP reader keeps trailing optional whitespace in header values, so the
// instrumentation must trim it before parsing the Host authority.

///|
struct HostOwsRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for HostOwsRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for HostOwsRecordingExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
async test "server span parses a host header with trailing whitespace" {
  let exporter : HostOwsRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="host-ows-test",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("host-ows-test")
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
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET /ows HTTP/1.1\r\nHost: example.com:8080 \t\r\nConnection: close\r\n\r\n",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("example.com")),
    )
    assert_eq(
      data.attributes.get(@sdk.SERVER_PORT),
      Some(@sdk.IntValue(8080)),
    )
  }
}
