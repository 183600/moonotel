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
