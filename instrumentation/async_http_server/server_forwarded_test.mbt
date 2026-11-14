// Integration tests for `server.address`/`server.port`/`url.scheme` when a
// reverse proxy supplies `Forwarded` or `X-Forwarded-*` headers.

///|
fn forwarded_tracer(
  scope : String,
) -> (@sdk.Tracer, @sdk.InMemorySpanExporter) {
  let exporter = @sdk.InMemorySpanExporter::new()
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="forwarded-test",
  ).with_span_processor(processor)
  (provider.get_tracer(scope), exporter)
}

///|
async fn send_forwarded_request(port : Int32, request : String) -> Unit {
  let connection = @socket.Tcp::connect(
    @socket.Addr::parse("127.0.0.1:\{port}"),
  )
  connection.write(request)
  let _ = @async.with_timeout(5000, () => connection.read_all().text())
  connection.close()
}

///|
async test "server uses X-Forwarded-Host and X-Forwarded-Proto" {
  let (tracer, exporter) = forwarded_tracer("forwarded-x-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => call.respond(204), tracer~)
    }
    send_forwarded_request(
      port,
      "GET /items HTTP/1.1\r\nHost: backend.internal\r\nX-Forwarded-Host: public.example.com:8443\r\nX-Forwarded-Proto: https\r\nConnection: close\r\n\r\n",
    )
    @async.sleep(50)
    assert_eq(exporter.exported_spans().length(), 1)
    let data = exporter.exported_spans()[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("public.example.com")),
    )
    assert_eq(data.attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(8443)))
    assert_eq(
      data.attributes.get(@sdk.URL_SCHEME),
      Some(@sdk.StringValue("https")),
    )
  }
}

///|
async test "Forwarded host overrides the absolute-form target and X-Forwarded-Host" {
  let (tracer, exporter) = forwarded_tracer("forwarded-precedence-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => call.respond(204), tracer~)
    }
    send_forwarded_request(
      port,
      "GET http://backend.internal:8080/items HTTP/1.1\r\nHost: backend.internal\r\nForwarded: for=192.0.2.1;host=public.example.com:9443;proto=https\r\nX-Forwarded-Host: ignored.example.com\r\nConnection: close\r\n\r\n",
    )
    @async.sleep(50)
    assert_eq(exporter.exported_spans().length(), 1)
    let data = exporter.exported_spans()[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("public.example.com")),
    )
    assert_eq(data.attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(9443)))
    assert_eq(
      data.attributes.get(@sdk.URL_SCHEME),
      Some(@sdk.StringValue("https")),
    )
    assert_eq(
      data.attributes.get(@sdk.URL_PATH),
      Some(@sdk.StringValue("/items")),
    )
  }
}

///|
async test "Forwarded host without a port uses the forwarded scheme default" {
  let (tracer, exporter) = forwarded_tracer("forwarded-default-port-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => call.respond(204), tracer~)
    }
    send_forwarded_request(
      port,
      "GET /items HTTP/1.1\r\nHost: backend.internal\r\nForwarded: host=public.example.com;proto=https\r\nConnection: close\r\n\r\n",
    )
    @async.sleep(50)
    assert_eq(exporter.exported_spans().length(), 1)
    let data = exporter.exported_spans()[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("public.example.com")),
    )
    assert_eq(data.attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(443)))
    assert_eq(
      data.attributes.get(@sdk.URL_SCHEME),
      Some(@sdk.StringValue("https")),
    )
  }
}

///|
async test "server records the original client from Forwarded for" {
  let (tracer, exporter) = forwarded_tracer("forwarded-client-test")
  @async.with_task_group() <| group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_with_client_address_on(
        server,
        call => call.respond(204),
        tracer~,
      )
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    let peer_port = connection.addr().port()
    connection.write(
      "GET /items HTTP/1.1\r\nHost: backend.internal\r\nForwarded: for=\"[2001:db8::1]:4711\"\r\nConnection: close\r\n\r\n",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.exported_spans().length(), 1)
    let data = exporter.exported_spans()[0]
    assert_eq(
      data.attributes.get(@sdk.CLIENT_ADDRESS),
      Some(@sdk.StringValue("2001:db8::1")),
    )
    assert_eq(data.attributes.get(@sdk.CLIENT_PORT), Some(@sdk.IntValue(4711)))
    assert_eq(
      data.attributes.get(@sdk.NETWORK_PEER_ADDRESS),
      Some(@sdk.StringValue("127.0.0.1")),
    )
    assert_eq(
      data.attributes.get(@sdk.NETWORK_PEER_PORT),
      Some(@sdk.IntValue(peer_port.to_int64())),
    )
  }
}

///|
async test "quoted Forwarded values keep separators and escapes inside parameters" {
  let (tracer, exporter) = forwarded_tracer("forwarded-quoted-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => call.respond(204), tracer~)
    }
    send_forwarded_request(
      port,
      "GET /items HTTP/1.1\r\nHost: backend.internal\r\nForwarded: FOR=\"192\\.0\\.2\\.1\";Host=\"public\\.example\\.com:9443\";Proto=\"https\";ext=\"a;b,c\\\"d\"\r\nX-Forwarded-Host: ignored.example.com\r\nX-Forwarded-For: 203.0.113.7\r\nConnection: close\r\n\r\n",
    )
    @async.sleep(50)
    assert_eq(exporter.exported_spans().length(), 1)
    let data = exporter.exported_spans()[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("public.example.com")),
    )
    assert_eq(data.attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(9443)))
    assert_eq(
      data.attributes.get(@sdk.URL_SCHEME),
      Some(@sdk.StringValue("https")),
    )
    assert_eq(
      data.attributes.get(@sdk.CLIENT_ADDRESS),
      Some(@sdk.StringValue("192.0.2.1")),
    )
    assert_eq(data.attributes.get(@sdk.CLIENT_PORT), None)
  }
}

///|
async test "X-Forwarded-For without a port does not reuse the peer port" {
  let (tracer, exporter) = forwarded_tracer("x-forwarded-client-test")
  @async.with_task_group() <| group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_with_client_address_on(
        server,
        call => call.respond(204),
        tracer~,
      )
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    let peer_port = connection.addr().port()
    connection.write(
      "GET /items HTTP/1.1\r\nHost: backend.internal\r\nX-Forwarded-For: 203.0.113.7\r\nConnection: close\r\n\r\n",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.exported_spans().length(), 1)
    let data = exporter.exported_spans()[0]
    assert_eq(
      data.attributes.get(@sdk.CLIENT_ADDRESS),
      Some(@sdk.StringValue("203.0.113.7")),
    )
    assert_eq(data.attributes.get(@sdk.CLIENT_PORT), None)
    assert_eq(
      data.attributes.get(@sdk.NETWORK_PEER_PORT),
      Some(@sdk.IntValue(peer_port.to_int64())),
    )
  }
}

///|
async test "an unusable Forwarded for falls back to the peer, not X-Forwarded-For" {
  let (tracer, exporter) = forwarded_tracer("forwarded-client-unknown-test")
  @async.with_task_group() <| group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_with_client_address_on(
        server,
        call => call.respond(204),
        tracer~,
      )
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    let peer_port = connection.addr().port()
    connection.write(
      "GET /items HTTP/1.1\r\nHost: backend.internal\r\nForwarded: for=unknown\r\nX-Forwarded-For: 203.0.113.7\r\nConnection: close\r\n\r\n",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_eq(exporter.exported_spans().length(), 1)
    let data = exporter.exported_spans()[0]
    assert_eq(
      data.attributes.get(@sdk.CLIENT_ADDRESS),
      Some(@sdk.StringValue("127.0.0.1")),
    )
    assert_eq(
      data.attributes.get(@sdk.CLIENT_PORT),
      Some(@sdk.IntValue(peer_port.to_int64())),
    )
  }
}

///|
async test "server falls back from an invalid forwarded host" {
  let (tracer, exporter) = forwarded_tracer("forwarded-invalid-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => call.respond(204), tracer~)
    }
    send_forwarded_request(
      port,
      "GET /items HTTP/1.1\r\nHost: example.com:9090\r\nForwarded: host=\"bad host\"\r\nConnection: close\r\n\r\n",
    )
    @async.sleep(50)
    assert_eq(exporter.exported_spans().length(), 1)
    let data = exporter.exported_spans()[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("example.com")),
    )
    assert_eq(data.attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(9090)))
    assert_eq(
      data.attributes.get(@sdk.URL_SCHEME),
      Some(@sdk.StringValue("http")),
    )
  }
}

///|
async test "Forwarded host with userinfo is ignored" {
  let (tracer, exporter) = forwarded_tracer("forwarded-host-userinfo-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => call.respond(204), tracer~)
    }
    send_forwarded_request(
      port,
      "GET /items HTTP/1.1\r\nHost: backend.internal:8080\r\nForwarded: host=user@evil.example:9443\r\nX-Forwarded-Host: public.example.com:8443\r\nConnection: close\r\n\r\n",
    )
    @async.sleep(50)
    assert_eq(exporter.exported_spans().length(), 1)
    let data = exporter.exported_spans()[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("public.example.com")),
    )
    assert_eq(data.attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(8443)))
  }
}

///|
async test "X-Forwarded-Host with userinfo is ignored" {
  let (tracer, exporter) = forwarded_tracer("x-forwarded-host-userinfo-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => call.respond(204), tracer~)
    }
    send_forwarded_request(
      port,
      "GET /items HTTP/1.1\r\nHost: backend.internal:9090\r\nX-Forwarded-Host: user@evil.example:8443\r\nConnection: close\r\n\r\n",
    )
    @async.sleep(50)
    assert_eq(exporter.exported_spans().length(), 1)
    let data = exporter.exported_spans()[0]
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("backend.internal")),
    )
    assert_eq(data.attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(9090)))
  }
}
