// Blackbox tests for the client address semantic-convention attribute of the
// server instrumentation.

struct ClientAddressRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

pub impl @sdk.SpanExporter for ClientAddressRecordingExporter with export_spans(self, spans) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

pub impl @sdk.SpanExporter for ClientAddressRecordingExporter with shutdown(self) {
  let _ = self
}

async test "server span does not record the listen address as client.address" {
  let exporter : ClientAddressRecordingExporter = { spans: Ref([]) }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(service_name="client-addr-test")
    .with_span_processor(processor)
  let tracer = provider.get_tracer("client-addr-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let seen_client_addr : Ref[String?] = Ref(None)
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => {
          seen_client_addr.val = Some(call.connection.client_addr().to_string())
          call.respond(200, body="ok")
        },
        tracer=tracer,
      )
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET /client-address HTTP/1.1\r\nHost: 127.0.0.1:\{port}\r\nConnection: close\r\n\r\n",
    )
    let _ = connection.read_all()
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    // `@http.ServerConnection::client_addr()` returns the local listen
    // address of the server, not the address of the peer, so the server span
    // must not record it as `client.address`.
    assert_eq(seen_client_addr.val, Some(server.addr.to_string()))
    let data = exporter.spans.val[0]
    assert_eq(data.attributes.get(@sdk.CLIENT_ADDRESS), None)
    // `server.address`/`server.port` still come from the request's Host
    // header.
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("127.0.0.1")),
    )
    assert_eq(
      data.attributes.get(@sdk.SERVER_PORT),
      Some(@sdk.IntValue(port.to_int64())),
    )
  }
}
