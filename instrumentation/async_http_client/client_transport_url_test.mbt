// Integration tests for RFC 3986 URL forms that the HTTP transport only
// accepts after the client instrumentation normalizes them.

///|
async test "client accepts an uppercase HTTP scheme" {
  let (tracer, exporter) = test_tracer("client-transport-uppercase")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(200, "OK")
      })
    }
    let url = "HTTP://127.0.0.1:\{port}/uppercase"
    let (response, body) = @async_http_client.get(
      url,
      tracer~,
      context=@context.Context::root(),
    )
    assert_eq(response.code, 200)
    assert_eq(body.text(), "")
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.attributes.get(@sdk.URL_FULL), Some(@sdk.StringValue(url)))
    assert_eq(
      data.attributes.get(@sdk.URL_SCHEME),
      Some(@sdk.StringValue("http")),
    )
    assert_eq(
      data.attributes.get(@sdk.URL_PATH),
      Some(@sdk.StringValue("/uppercase")),
    )
    assert_eq(
      data.attributes.get(@sdk.SERVER_PORT),
      Some(@sdk.IntValue(port.to_int64())),
    )
  }
}

///|
async test "client without a tracer accepts an uppercase HTTP scheme" {
  @sdk.shutdown_global_tracer_provider()
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(200, "OK")
      })
    }
    let url = "HTTP://127.0.0.1:\{port}/untraced"
    let (response, body) = @async_http_client.get(url)
    assert_eq(response.code, 200)
    assert_eq(body.text(), "")
  }
}

///|
async test "client without a tracer sends a root target for a query-only URL with a fragment" {
  @sdk.shutdown_global_tracer_provider()
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let observed_target : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        observed_target.val = request.path
        conn.send_response(200, "OK")
      })
    }
    let url = "http://127.0.0.1:\{port}?x=1#frag"
    let (response, body) = @async_http_client.get(url)
    assert_eq(response.code, 200)
    assert_eq(body.text(), "")
    // The fragment is not sent, and the missing path becomes `/`.
    assert_eq(observed_target.val, "/?x=1")
  }
}

///|
async test "client without a tracer honors a caller-supplied Content-Length" {
  @sdk.shutdown_global_tracer_provider()
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let received_content_length : Ref[String?] = Ref(None)
    let received_transfer_encoding : Ref[String?] = Ref(None)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, body, conn) => {
        let _ = body.read_all()
        received_content_length.val = request.headers.get(
          @http.CaseInsensitiveString("content-length"),
        )
        received_transfer_encoding.val = request.headers.get(
          @http.CaseInsensitiveString("transfer-encoding"),
        )
        conn.send_response(200, "OK")
      })
    }
    let url = "http://127.0.0.1:\{port}/untraced-length"
    let (response, body) = @async_http_client.post(
      url,
      "payload",
      headers={ "Content-Length": "7", "Transfer-Encoding": "gzip" },
    )
    assert_eq(response.code, 200)
    assert_eq(body.text(), "")
    assert_eq(received_content_length.val, Some("7"))
    assert_eq(received_transfer_encoding.val, None)
  }
}

///|
async test "client sends a root target for a query-only URL with a fragment" {
  let (tracer, exporter) = test_tracer("client-transport-root-target")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let observed_target : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        observed_target.val = request.path
        conn.send_response(200, "OK")
      })
    }
    let url = "http://127.0.0.1:\{port}?x=1#frag"
    let (response, body) = @async_http_client.get(
      url,
      tracer~,
      context=@context.Context::root(),
    )
    assert_eq(response.code, 200)
    assert_eq(body.text(), "")
    // The fragment is not sent, and the missing path becomes `/`.
    assert_eq(observed_target.val, "/?x=1")
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.attributes.get(@sdk.URL_FULL), Some(@sdk.StringValue(url)))
    assert_eq(
      data.attributes.get(@sdk.URL_PATH),
      Some(@sdk.StringValue("/")),
    )
    assert_eq(
      data.attributes.get(@sdk.URL_QUERY),
      Some(@sdk.StringValue("x=1")),
    )
  }
}
