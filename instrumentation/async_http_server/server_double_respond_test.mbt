// A handler must send exactly one response per request. A second
// `ServerCall::respond` is ignored so that a keep-alive connection cannot
// receive a stray response head that a client would read as the answer to its
// next request.

///|
struct DoubleRespondExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for DoubleRespondExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for DoubleRespondExporter with fn shutdown(self) {
  let _ = self
}

///|
fn double_respond_tracer(
  scope : String,
) -> (@sdk.Tracer, DoubleRespondExporter) {
  let exporter : DoubleRespondExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="double-respond-test",
  ).with_span_processor(processor)
  (provider.get_tracer(scope), exporter)
}

///|
async test "a second respond keeps the first response and its span status" {
  let (tracer, exporter) = double_respond_tracer("double-respond")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => {
          call.respond(200, body="first")
          call.respond(500, body="second")
        },
        tracer~,
      )
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/double")
    assert_eq(response.code, 200)
    assert_eq(body.text(), "first")
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE),
      Some(@sdk.IntValue(200)),
    )
    assert_eq(data.status, @api.StatusCode::Unset)
  }
}
