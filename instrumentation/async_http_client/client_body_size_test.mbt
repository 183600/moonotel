// Tests for the HTTP body size semantic-convention attributes recorded by the
// client instrumentation.

///|
struct BodySizeRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for BodySizeRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for BodySizeRecordingExporter with fn shutdown(self) {
  let _ = self
}

///|
fn body_size_tracer(scope : String) -> (@sdk.Tracer, BodySizeRecordingExporter) {
  let exporter : BodySizeRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(service_name="body-size-test").with_span_processor(
    processor,
  )
  (provider.get_tracer(scope), exporter)
}

///|
async test "client span records request and response body sizes" {
  let (tracer, exporter) = body_size_tracer("client-body-size")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        let _ = body.read_all()
        conn.send_response(200, "OK")
        conn.write("hello!")
        conn.end_response()
      })
    }
    let (response, body) = @async_http_client.post(
      "http://127.0.0.1:\{port}/items",
      "payload",
      tracer~,
    )
    assert_eq(response.code, 200)
    assert_eq(body.text(), "hello!")
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.HTTP_REQUEST_BODY_SIZE),
      Some(@sdk.IntValue(7)),
    )
    assert_eq(
      data.attributes.get(@sdk.HTTP_RESPONSE_BODY_SIZE),
      Some(@sdk.IntValue(6)),
    )
  }
}

///|
async test "client span omits body sizes when both bodies are empty" {
  let (tracer, exporter) = body_size_tracer("client-body-size-empty")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(200, "OK")
      })
    }
    let (response, _body) = @async_http_client.get(
      "http://127.0.0.1:\{port}/empty",
      tracer~,
    )
    assert_eq(response.code, 200)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.attributes.get(@sdk.HTTP_REQUEST_BODY_SIZE), None)
    assert_eq(data.attributes.get(@sdk.HTTP_RESPONSE_BODY_SIZE), None)
  }
}
