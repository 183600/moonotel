// Blackbox tests for the network protocol semantic-convention attributes
// recorded by the client instrumentation.

struct ClientProtocolExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

pub impl @sdk.SpanExporter for ClientProtocolExporter with export_spans(self, spans) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

pub impl @sdk.SpanExporter for ClientProtocolExporter with shutdown(self) {
  let _ = self
}

async test "client spans carry the network protocol attributes" {
  let exporter : ClientProtocolExporter = { spans: Ref([]) }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(service_name="client-protocol")
    .with_span_processor(processor)
  let tracer = provider.get_tracer("client-protocol")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(200, "OK")
      })
    }
    let (response, _body) = get("http://127.0.0.1:\{port}/protocol", tracer=tracer)
    assert_eq(response.code, 200)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.NETWORK_PROTOCOL_NAME),
      Some(@sdk.StringValue("http")),
    )
    assert_eq(
      data.attributes.get(@sdk.NETWORK_PROTOCOL_VERSION),
      Some(@sdk.StringValue("1.1")),
    )
  }
}
