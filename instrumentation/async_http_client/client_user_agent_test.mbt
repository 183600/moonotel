// The client records the `User-Agent` header it actually sends as the
// `user_agent.original` semantic-convention attribute, without the surrounding
// HTTP optional whitespace.

///|
struct UserAgentRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for UserAgentRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for UserAgentRecordingExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
async test "client span records the trimmed user agent" {
  let exporter : UserAgentRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(service_name="client-user-agent")
    .with_span_processor(processor)
  let tracer = provider.get_tracer("client-user-agent")
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
      headers={ "user-agent": "  agent/1.0 \t" },
      tracer~,
    )
    assert_eq(response.code, 200)
    assert_eq(exporter.spans.val.length(), 1)
    assert_eq(
      exporter.spans.val[0].attributes.get(@sdk.USER_AGENT_ORIGINAL),
      Some(@sdk.StringValue("agent/1.0")),
    )
  }
}
