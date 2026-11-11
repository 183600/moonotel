// The response transport uses `Content-Length` to select its body framing. A
// negative or malformed value cannot describe a body and must not be forwarded:
// the transport would otherwise wait for a negative number of bytes and abort
// the connection task when the response ends.

///|
async test "server drops an invalid response content-length" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        call.respond(200, body="ok", headers={ "Content-Length": "-1" })
      })
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/negative")
    assert_eq(response.code, 200)
    assert_eq(body.text(), "ok")
  }
}

///|
async test "server drops a non-numeric response content-length" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        call.respond(200, body="ok", headers={ "Content-Length": "oops" })
      })
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/malformed")
    assert_eq(response.code, 200)
    assert_eq(body.text(), "ok")
  }
}
