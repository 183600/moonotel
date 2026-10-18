// Integration tests for the OTLP/JSON encoding of the async exporter, driven
// against a real loopback `@http.Server`.

///|
async test "json export sends application/json and a JSON body" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let content_type : Ref[String] = Ref("")
    let received : Ref[Bytes] = Ref(b"")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, body, conn) => {
        content_type.val = request.headers
          .get(@http.CaseInsensitiveString("content-type"))
          .unwrap_or("")
        received.val = body.read_all().binary()
        conn.send_response(200, "OK")
        conn.write(b"{}")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      protocol="http/json",
    )
    let result = @otlp_async.export_spans(config, [test_span_data()])
    assert_true(result.is_success())
    assert_eq(content_type.val, "application/json")
    let text = @utf8.decode_lossy(received.val.exact_view())
    assert_true(text.contains("\"resourceSpans\""))
    assert_true(text.contains("\"otlp-async-test-op\""))
  }
}

///|
async test "json export reports partial success as a failure" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(200, "OK")
        conn.write(b"{\"partialSuccess\":{\"rejectedSpans\":\"1\"}}")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      protocol="http/json",
    )
    let result = @otlp_async.export_spans(config, [test_span_data()])
    match result {
      @sdk.ExportFailure(message) =>
        assert_true(message.contains("rejected 1 span(s)"))
      @sdk.ExportSuccess => fail("expected a partial success failure")
    }
  }
}
