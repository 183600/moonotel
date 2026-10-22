// A handler may request that the connection be closed and still send the
// response afterwards: the close takes effect after the response is written.

///|
struct CloseConnectionExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for CloseConnectionExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for CloseConnectionExporter with fn shutdown(self) {
  let _ = self
}

///|
fn close_connection_tracer(
  scope : String,
) -> (@sdk.Tracer, CloseConnectionExporter) {
  let exporter : CloseConnectionExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="close-connection-test",
  ).with_span_processor(processor)
  (provider.get_tracer(scope), exporter)
}

///|
async test "close_connection before respond defers the close until after the response" {
  let (tracer, exporter) = close_connection_tracer("close-connection")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => {
          call.close_connection()
          call.respond(200, body="closed-after-response")
        },
        tracer~,
      )
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/close")
    assert_eq(response.code, 200)
    assert_eq(body.text(), "closed-after-response")
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    assert_eq(
      exporter.spans.val[0].attributes.get(
        @sdk.HTTP_RESPONSE_STATUS_CODE,
      ),
      Some(@sdk.IntValue(200)),
    )
  }
}

///|
async test "close_connection without respond closes the connection" {
  let (tracer, _) = close_connection_tracer("close-connection-no-response")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.close_connection(),
        tracer~,
      )
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write("GET /close HTTP/1.1\r\nHost: test\r\n\r\n")
    // The server closes the connection without a response, so reading reaches
    // end-of-stream instead of waiting forever.
    let data = @async.with_timeout(5000, () => connection.read_all().text())
    assert_eq(data, "")
    connection.close()
  }
}
