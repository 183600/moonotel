// Blackbox test for the primary `run_server` entry point: it records the
// address of the TCP peer as `client.address`/`client.port` on SERVER spans.

///|
struct RunServerRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for RunServerRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for RunServerRecordingExporter with fn shutdown(self) {
  let _ = self
}

///|
async test "run_server records client.address and client.port" {
  let exporter : RunServerRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(service_name="run-server-test").with_span_processor(
    processor,
  )
  let tracer = provider.get_tracer("run-server-test")
  @async.with_task_group() <| group => {
    // `run_server` owns its listener, so reserve a free port by binding and
    // releasing one first, then run the server on it.
    let probe = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let port = probe.addr.port()
    probe.close()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server(
        @socket.Addr::parse("127.0.0.1:\{port}"),
        call => call.respond(200, body="ok"),
        tracer~,
      )
    }
    // `run_server` binds its listener inside the spawned task, so retry the
    // connection until the server is accepting.
    let mut connected : @socket.Tcp? = None
    let mut attempt = 0
    while connected is None && attempt < 200 {
      connected = Some(
        @socket.Tcp::connect(@socket.Addr::parse("127.0.0.1:\{port}")),
      ) catch {
        _ => None
      }
      if connected is None {
        @async.sleep(10)
      }
      attempt = attempt + 1
    }
    let connection = connected.unwrap()
    // The local address of the client socket is the peer address the server
    // must observe.
    let client_port = connection.addr().port()
    connection.write(
      "GET /run-server HTTP/1.1\r\nHost: 127.0.0.1:\{port}\r\nConnection: close\r\n\r\n",
    )
    let _ = connection.read_all()
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.name, "GET")
    assert_eq(
      data.attributes.get(@sdk.CLIENT_ADDRESS),
      Some(@sdk.StringValue("127.0.0.1")),
    )
    assert_eq(
      data.attributes.get(@sdk.CLIENT_PORT),
      Some(@sdk.IntValue(client_port.to_int64())),
    )
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
