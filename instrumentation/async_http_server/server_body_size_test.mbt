// Tests for the HTTP response body size semantic-convention attribute
// recorded by the server instrumentation.

///|
struct BodySizeServerExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for BodySizeServerExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for BodySizeServerExporter with fn shutdown(self) {
  let _ = self
}

///|
fn body_size_server_tracer(
  scope : String,
) -> (@sdk.Tracer, BodySizeServerExporter) {
  let exporter : BodySizeServerExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="server-body-size-test",
  ).with_span_processor(processor)
  (provider.get_tracer(scope), exporter)
}

///|
async test "server span records the response body size in UTF-8 bytes" {
  let (tracer, exporter) = body_size_server_tracer("server-body-size")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(200, body="héllo"),
        tracer~,
      )
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/greet")
    assert_eq(response.code, 200)
    assert_eq(body.text(), "héllo")
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    // `é` needs two UTF-8 bytes, so the body is six bytes, not five
    // characters.
    assert_eq(
      data.attributes.get(@sdk.HTTP_RESPONSE_BODY_SIZE),
      Some(@sdk.IntValue(6)),
    )
  }
}

///|
async test "server span omits the response body size without a body" {
  let (tracer, exporter) = body_size_server_tracer("server-body-size-empty")
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
    let (response, _body) = @http.get("http://127.0.0.1:\{port}/none")
    assert_eq(response.code, 204)
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.attributes.get(@sdk.HTTP_RESPONSE_BODY_SIZE), None)
  }
}
