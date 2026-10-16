// Regression test: an untraced server request (no tracer available) must not
// pop a context that the caller attached before starting the server.

async test "untraced_server_does_not_pop_caller_context" {
  let parent = @api.span_context(
    Array::make(16, 5),
    Array::make(8, 6),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let previous = @context.attach(@context.Context::root().with_span(parent))
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      run_server_on(server, call => {
        call.respond(204)
      })
    }
    let (response, _body) = @http.get("http://127.0.0.1:\{port}/plain")
    assert_eq(response.code, 204)
    @async.sleep(50)
  }
  let current = @context.current_span_context()
  @context.detach(previous)
  assert_true(current is Some(_))
}
