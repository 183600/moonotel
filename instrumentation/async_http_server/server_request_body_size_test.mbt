// The server records the declared HTTP request body size, following the HTTP
// semantic conventions.

///|
struct RequestBodySizeRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for RequestBodySizeRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for RequestBodySizeRecordingExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
async test "server span records the declared request body size" {
  let exporter : RequestBodySizeRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="request-body-size-test",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("request-body-size-test")
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
      "POST /upload HTTP/1.1\r\nHost: 127.0.0.1:\{port}\r\nContent-Length: 5\r\nConnection: close\r\n\r\nhello",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    assert_eq(
      exporter.spans.val[0].attributes.get(@sdk.HTTP_REQUEST_BODY_SIZE),
      Some(@sdk.IntValue(5)),
    )
  }
}

///|
async test "server span omits the request body size without Content-Length" {
  let exporter : RequestBodySizeRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="request-body-size-test",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("request-body-size-test")
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
      "GET /no-body HTTP/1.1\r\nHost: 127.0.0.1:\{port}\r\nConnection: close\r\n\r\n",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    assert_eq(
      exporter.spans.val[0].attributes.get(@sdk.HTTP_REQUEST_BODY_SIZE),
      None,
    )
  }
}

///|
async test "server span mirrors the transport's underscore content-length parsing" {
  let exporter : RequestBodySizeRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="request-body-size-test",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("request-body-size-test")
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
      "POST /upload HTTP/1.1\r\nHost: 127.0.0.1:\{port}\r\nContent-Length: 1_0\r\nConnection: close\r\n\r\nhellohello",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    assert_eq(
      exporter.spans.val[0].attributes.get(@sdk.HTTP_REQUEST_BODY_SIZE),
      Some(@sdk.IntValue(10)),
    )
  }
}
