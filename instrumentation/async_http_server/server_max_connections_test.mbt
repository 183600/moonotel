// `max_connections` must limit how many connections are served at once while
// still allowing queued connections to proceed as earlier ones finish.

///|
async test "max_connections limits concurrent server connections" {
  let entered = @async.Semaphore(1, initial_value=0)
  let release = @async.Semaphore(1, initial_value=0)
  let entered_count : Ref[Int32] = Ref(0)
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, async fn(call) {
        entered_count.val = entered_count.val + 1
        entered.release()
        release.acquire()
        call.respond(200, body="ok")
      }, max_connections=1)
    }
    let first = group.spawn(() => @http.get("http://127.0.0.1:\{port}/one"))
    entered.acquire()
    assert_eq(entered_count.val, 1)
    let second = group.spawn(() => @http.get("http://127.0.0.1:\{port}/two"))
    // With the only slot occupied, the second connection is accepted but its
    // handler must not start until the first connection finishes.
    @async.sleep(100)
    assert_eq(entered_count.val, 1)
    release.release()
    entered.acquire()
    assert_eq(entered_count.val, 2)
    release.release()
    let (first_response, first_body) = first.wait()
    let (second_response, second_body) = second.wait()
    assert_eq(first_response.code, 200)
    assert_eq(first_body.text(), "ok")
    assert_eq(second_response.code, 200)
    assert_eq(second_body.text(), "ok")
  }
}
