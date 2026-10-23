// Integration tests for `server.address`/`server.port` with an absolute-form
// request target: per the HTTP semantic conventions both must come from the
// authority of the request target, not from the Host header.

///|
struct AbsoluteAuthorityExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for AbsoluteAuthorityExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for AbsoluteAuthorityExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
fn absolute_authority_tracer(
  scope : String,
) -> (@sdk.Tracer, AbsoluteAuthorityExporter) {
  let exporter : AbsoluteAuthorityExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="instrumentation-test",
  ).with_span_processor(processor)
  (provider.get_tracer(scope), exporter)
}

///|
async test "server host attributes follow the absolute-form authority" {
  let (tracer, exporter) = absolute_authority_tracer(
    "server-test-absolute-authority",
  )
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
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET http://backend.internal:8080/items HTTP/1.1\r\nHost: external.example.com\r\nConnection: close\r\n\r\n",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("backend.internal")),
    )
    assert_eq(
      data.attributes.get(@sdk.SERVER_PORT),
      Some(@sdk.IntValue(8080)),
    )
    assert_eq(
      data.attributes.get(@sdk.URL_PATH),
      Some(@sdk.StringValue("/items")),
    )
  }
}

///|
async test "server host attributes ignore userinfo in the absolute-form authority" {
  let (tracer, exporter) = absolute_authority_tracer(
    "server-test-absolute-authority-userinfo",
  )
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
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET http://user:secret@backend.internal:8080/items HTTP/1.1\r\nHost: external.example.com\r\nConnection: close\r\n\r\n",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("backend.internal")),
    )
    assert_eq(
      data.attributes.get(@sdk.SERVER_PORT),
      Some(@sdk.IntValue(8080)),
    )
  }
}

///|
async test "server strips userinfo from a non-http absolute-form target" {
  let (tracer, exporter) = absolute_authority_tracer(
    "server-test-absolute-authority-generic-scheme",
  )
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
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET ftp://user:secret@backend.internal:21/items?q=1 HTTP/1.1\r\nHost: external.example.com\r\nConnection: close\r\n\r\n",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.URL_PATH),
      Some(@sdk.StringValue("/items")),
    )
    assert_eq(
      data.attributes.get(@sdk.URL_QUERY),
      Some(@sdk.StringValue("q=1")),
    )
    // Server attributes keep their existing http(s)-absolute-form contract,
    // so the Host header remains the fallback for an unknown scheme.
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("external.example.com")),
    )
  }
}

///|
async test "server host attributes keep the Host header for origin form" {
  let (tracer, exporter) = absolute_authority_tracer(
    "server-test-origin-authority",
  )
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
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET /items HTTP/1.1\r\nHost: example.com:9090\r\nConnection: close\r\n\r\n",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("example.com")),
    )
    assert_eq(
      data.attributes.get(@sdk.SERVER_PORT),
      Some(@sdk.IntValue(9090)),
    )
  }
}

///|
async test "server host attributes ignore userinfo in the Host header" {
  let (tracer, exporter) = absolute_authority_tracer(
    "server-test-host-userinfo",
  )
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
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET /items HTTP/1.1\r\nHost: user:secret@example.com:9090\r\nConnection: close\r\n\r\n",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("example.com")),
    )
    assert_eq(
      data.attributes.get(@sdk.SERVER_PORT),
      Some(@sdk.IntValue(9090)),
    )
  }
}
