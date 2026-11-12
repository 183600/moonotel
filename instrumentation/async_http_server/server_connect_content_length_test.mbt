// RFC 9110 section 8.6 forbids `Content-Length` on a successful response to a
// CONNECT request, so the instrumentation must drop it before the transport
// writes the response headers.

///|
async test "server drops content-length on a successful CONNECT response" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        call.respond(200, headers={ "Content-Length": "7" })
      })
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\nConnection: close\r\n\r\n",
    )
    let response = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    assert_true(response.contains("200 OK"))
    assert_false(response.to_lower().contains("content-length"))
  }
}
