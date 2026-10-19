// Tests for HTTP/1.1 connection handling and the network protocol
// semantic-convention attributes of the server instrumentation.

///|
struct ProtocolRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for ProtocolRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for ProtocolRecordingExporter with fn shutdown(self) {
  let _ = self
}

///|
async test "Connection: close closes the socket after the response" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        call.respond(200, body="bye")
      })
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET /bye HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n",
    )
    // `read_all` only returns at EOF, so the timeout guards against the
    // connection staying open.
    let response = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    assert_true(response.contains("200 OK"))
    assert_true(response.contains("connection: close"))
    assert_true(response.contains("bye"))
  }
}

///|
async test "response Connection: close closes the socket" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let headers : Map[String, String] = Map([("Connection", "close")])
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        call.respond(200, body="closing", headers=headers)
      })
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write("GET /close HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n")
    let response = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    assert_true(response.contains("200 OK"))
    assert_true(response.to_lower().contains("connection: close"))
    assert_true(response.contains("closing"))
  }
}

///|
async test "keep-alive connections serve a second request" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        call.respond(200, body=call.path())
      })
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET /first HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: keep-alive\r\n\r\n",
    )
    // Chunked responses end with `\r\n0\r\n\r\n`; reading until that
    // terminator consumes exactly one response and leaves any buffered
    // follow-up data intact for the next read.
    let first = @async.with_timeout(5000, () => {
      connection.read_until("\r\n0\r\n\r\n")
    })
    assert_true(first.unwrap_or("").contains("200 OK"))
    assert_true(first.unwrap_or("").contains("/first"))
    connection.write(
      "GET /second HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n",
    )
    let second = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    assert_true(second.contains("200 OK"))
    assert_true(second.contains("/second"))
  }
}

///|
async test "server spans carry the network protocol attributes" {
  let exporter : ProtocolRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(service_name="protocol-test").with_span_processor(
    processor,
  )
  let tracer = provider.get_tracer("protocol-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(200, body="ok"),
        tracer~,
      )
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/protocol")
    assert_eq(response.code, 200)
    assert_eq(body.text(), "ok")
    @async.sleep(50)
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
