// Tests for the public `post_trace_request` entry point, which sends a
// caller-supplied OTLP request body instead of encoding spans itself.

///|
async test "post_trace_request sends a caller-supplied protobuf body" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let received : Ref[Bytes] = Ref(b"")
    let content_type : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, body, conn) => {
        received.val = body.read_all().binary()
        content_type.val = request.headers
          .get(@http.CaseInsensitiveString("content-type"))
          .unwrap_or("")
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    let payload = @otlp.encode_trace_request([test_span_data()])
    let result = @otlp_async.post_trace_request(config, payload)
    assert_true(result.is_success())
    assert_eq(received.val, payload)
    assert_eq(content_type.val, "application/x-protobuf")
  }
}

///|
async test "post_trace_request gzips a caller-supplied body when configured" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let received : Ref[Bytes] = Ref(b"")
    let encoding : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, body, conn) => {
        received.val = body.read_all().binary()
        encoding.val = request.headers
          .get(@http.CaseInsensitiveString("content-encoding"))
          .unwrap_or("")
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      compression="gzip",
    )
    let payload = @otlp.encode_trace_request([test_span_data()])
    let result = @otlp_async.post_trace_request(config, payload)
    assert_true(result.is_success())
    assert_eq(encoding.val, "gzip")
    let decoded = gunzip(received.val)
    assert_eq(decoded, payload)
  }
}
