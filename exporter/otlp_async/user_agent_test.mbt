// The async OTLP/HTTP transport identifies itself with a User-Agent header.
// An explicitly configured value wins, case-insensitively.

///|
async test "request sends the default user agent" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let observed : Ref[String] = Ref("")
    let requests : Ref[Int32] = Ref(0)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        requests.val = requests.val + 1
        observed.val = request.headers
          .get(@http.CaseInsensitiveString("user-agent"))
          .unwrap_or("")
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    let result = @otlp_async.export_spans(config, [accept_test_span_data()])
    assert_true(result.is_success())
    assert_eq(requests.val, 1)
    assert_eq(observed.val, "OTel-OTLP-Exporter-MoonBit/" + @sdk.SDK_VERSION)
  }
}

///|
async test "configured user agent overrides the default case-insensitively" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let observed : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        observed.val = request.headers
          .get(@http.CaseInsensitiveString("user-agent"))
          .unwrap_or("")
        conn.send_response(200, "OK")
      })
    }
    let headers : Map[String, String] = Map([], capacity=2)
    headers.set("User-Agent", "custom-agent/9.9")
    headers.set("USER-AGENT", "custom-agent/10.0")
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      headers~,
    )
    let result = @otlp_async.export_spans(config, [accept_test_span_data()])
    assert_true(result.is_success())
    assert_eq(observed.val, "custom-agent/10.0")
  }
}
