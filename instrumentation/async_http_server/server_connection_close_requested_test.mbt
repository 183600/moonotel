// `ServerCall::connection_close_requested` exposes the request's parsed
// `Connection` tokens to handlers that bypass `respond`'s automatic close.

///|
async test "connection_close_requested recognizes a close token" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        call.respond(
          200,
          body=if call.connection_close_requested() { "close" } else { "keep" },
        )
      })
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET /close HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: keep-alive, CLOSE\r\n\r\n",
    )
    let response = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    assert_true(response.contains("200 OK"))
    assert_true(response.contains("close"))
  }
}

///|
async test "connection_close_requested ignores other connection tokens" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        call.respond(
          200,
          body=if call.connection_close_requested() { "close" } else { "keep" },
        )
      })
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET /keep HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: keep-alive\r\n\r\n",
    )
    let response = @async.with_timeout(5000, () => {
      connection.read_until("\r\n0\r\n\r\n")
    })
    connection.close()
    assert_true(response.unwrap_or("").contains("200 OK"))
    assert_true(response.unwrap_or("").contains("keep"))
  }
}