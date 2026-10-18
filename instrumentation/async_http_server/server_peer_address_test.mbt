// Blackbox tests for `run_server_with_client_address`: the address of the
// TCP peer is recorded as `client.address` and `client.port` on SERVER spans.

///|
struct PeerAddressRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for PeerAddressRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for PeerAddressRecordingExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
fn peer_address_setup() -> (
  PeerAddressRecordingExporter,
  @sdk.Tracer
) {
  let exporter : PeerAddressRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="peer-address-test",
  ).with_span_processor(processor)
  (exporter, provider.get_tracer("peer-address-test"))
}

///|
async test "run_server_with_client_address records client.address and client.port" {
  let (exporter, tracer) = peer_address_setup()
  @async.with_task_group() <| group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_with_client_address_on(
        server,
        call => {
          call.respond(200, body="ok")
        },
        tracer~,
      )
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    // The local address of the client socket is the peer address the server
    // must observe.
    let client_port = connection.addr().port()
    connection.write(
      "GET /peer HTTP/1.1\r\nHost: 127.0.0.1:\{port}\r\nConnection: close\r\n\r\n",
    )
    let _ = connection.read_all()
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.CLIENT_ADDRESS),
      Some(@sdk.StringValue("127.0.0.1")),
    )
    assert_eq(
      data.attributes.get(@sdk.CLIENT_PORT),
      Some(@sdk.IntValue(client_port.to_int64())),
    )
    // `server.address`/`server.port` still come from the Host header.
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

///|
async test "run_server_with_client_address keeps the connection for a second request" {
  let (exporter, tracer) = peer_address_setup()
  @async.with_task_group() <| group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_with_client_address_on(
        server,
        call => {
          call.respond(200, body="ok")
        },
        tracer~,
      )
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write("GET /one HTTP/1.1\r\nHost: 127.0.0.1:\{port}\r\n\r\n")
    @async.sleep(50)
    connection.write(
      "GET /two HTTP/1.1\r\nHost: 127.0.0.1:\{port}\r\nConnection: close\r\n\r\n",
    )
    let _ = connection.read_all()
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 2)
    for data in exporter.spans.val {
      assert_eq(
        data.attributes.get(@sdk.CLIENT_ADDRESS),
        Some(@sdk.StringValue("127.0.0.1")),
      )
    }
  }
}

///|
async test "run_server_with_client_address records IPv6 client addresses" {
  // IPv6 loopback may be unavailable; skip the test in that case.
  let server_opt = try {
    Some(@socket.TcpServer(@socket.Addr::parse("[::1]:0")))
  } catch {
    _ => None
  }
  match server_opt {
    None => ()
    Some(server) => {
      let port = server.addr.port()
      let (exporter, tracer) = peer_address_setup()
      @async.with_task_group() <| group => {
        group.spawn_bg(no_wait=true) <| () => {
          @async_http_server.run_server_with_client_address_on(
            server,
            call => {
              call.respond(200, body="ok")
            },
            tracer~,
          )
        }
        let connection = @socket.Tcp::connect(
          @socket.Addr::parse("[::1]:\{port}"),
        )
        connection.write(
          "GET /v6 HTTP/1.1\r\nHost: [::1]:\{port}\r\nConnection: close\r\n\r\n",
        )
        let _ = connection.read_all()
        connection.close()
        @async.sleep(50)
        assert_eq(exporter.spans.val.length(), 1)
        // The IPv6 brackets are stripped from `client.address`.
        assert_eq(
          exporter.spans.val[0].attributes.get(@sdk.CLIENT_ADDRESS),
          Some(@sdk.StringValue("::1")),
        )
      }
    }
  }
}

///|
async test "run_server_with_client_address closes connections left unanswered" {
  let (exporter, tracer) = peer_address_setup()
  @async.with_task_group() <| group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_with_client_address_on(
        server,
        call => {
          let _ = call
        },
        tracer~,
      )
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write("GET /unanswered HTTP/1.1\r\nHost: 127.0.0.1:\{port}\r\n\r\n")
    // The server closes the connection because the handler sent no response.
    let _ = connection.read_all()
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    assert_eq(
      exporter.spans.val[0].attributes.get(@sdk.CLIENT_ADDRESS),
      Some(@sdk.StringValue("127.0.0.1")),
    )
  }
}
