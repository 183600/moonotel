// Even when no tracer is available, a request's extracted trace context must be
// installed for the handler instead of leaking the server task's ambient
// context.

///|
async test "server installs the incoming context without a tracer" {
  let parent_trace = "4bf92f359d1e75b7618a2d1f3c4e5a6b"
  let parent_span = "00f067aa0ba902b7"
  let seen : Ref[@api.SpanContext?] = Ref(None)
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        seen.val = @context.current_span_context()
        call.respond(200)
      })
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "GET /ctx HTTP/1.1\r\nHost: test\r\nTraceParent: 00-" +
      parent_trace +
      "-" +
      parent_span +
      "-01\r\nConnection: close\r\n\r\n",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
  }
  match seen.val {
    Some(context) => {
      assert_eq(context.trace_id_hex(), parent_trace)
      assert_eq(context.span_id_hex(), parent_span)
      assert_true(context.is_remote())
    }
    None => fail("the incoming trace context was not installed")
  }
}
