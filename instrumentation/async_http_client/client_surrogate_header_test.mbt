// Request header strings are encoded as UTF-8 by the HTTP transport. Unpaired
// UTF-16 surrogates must be replaced instead of aborting the request.

///|
async test "client request header values replace unpaired surrogates" {
  let high = String::from_array([(0xD800).unsafe_to_char()])
  let low = String::from_array([(0xDC00).unsafe_to_char()])
  let replacement = (0xFFFD).unsafe_to_char().to_string()
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let received : Ref[String?] = Ref(None)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        received.val = request.headers.get(
          @http.CaseInsensitiveString("x-surrogate"),
        )
        conn.send_response(200, "OK")
      })
    }
    let headers : Map[String, String] = Map([
      ("x-surrogate", "v" + high + "w" + low + "x"),
    ])
    let (response, _body) = @async_http_client.get(
      "http://127.0.0.1:\{port}/header",
      headers~,
    )
    assert_eq(response.code, 200)
    assert_eq(received.val, Some("v" + replacement + "w" + replacement + "x"))
  }
}
