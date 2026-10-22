// A handler that returns without sending a response must not leave the
// connection waiting for another request: `run_server_on` closes it so the
// client observes end-of-stream instead of hanging.

///|
async test "run_server_on closes the connection when the handler sends no response" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, _call => ())
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write("GET /no-response HTTP/1.1\r\nHost: test\r\n\r\n")
    // The server closes the connection without a response, so reading reaches
    // end-of-stream instead of waiting for the next request.
    let data = @async.with_timeout(5000, () => connection.read_all().text())
    assert_eq(data, "")
    connection.close()
  }
}
