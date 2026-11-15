// The client records the `User-Agent` that the async HTTP client supplies when
// the caller does not set one, not only an explicitly configured value.

///|
struct DefaultUserAgentRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for DefaultUserAgentRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for DefaultUserAgentRecordingExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
async test "client span records the transport supplied user agent" {
  let exporter : DefaultUserAgentRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="client-default-user-agent",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("client-default-user-agent")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(200, "OK")
      })
    }
    let (response, _body) = @async_http_client.get(
      "http://127.0.0.1:\{port}/agent",
      tracer~,
    )
    assert_eq(response.code, 200)
    assert_eq(exporter.spans.val.length(), 1)
    assert_eq(
      exporter.spans.val[0].attributes.get(@sdk.USER_AGENT_ORIGINAL),
      Some(@sdk.StringValue("moonbit-http-client/1.1")),
    )
  }
}
