async test "server reconciles response content-length with utf8 body bytes" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        call.respond(200, body="héllo", headers={ "Content-Length": "5" })
      })
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/length")
    assert_eq(response.code, 200)
    assert_eq(body.text(), "héllo")
  }
}

async test "server reconciles response content-length without a body" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        call.respond(200, headers={ "Content-Length": "5" })
      })
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/empty")
    assert_eq(response.code, 200)
    assert_eq(body.text(), "")
  }
}
