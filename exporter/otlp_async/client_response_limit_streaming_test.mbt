// The async transport enforces the response size limit while reading instead
// of buffering the whole body first. This keeps a large or gzip-expanded
// response from being fully materialized before it is rejected.

///|
async test "response size limit is enforced before the body ends" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        let _ = body.read_all()
        conn.send_response(200, "OK")
        conn.write(b"ab")
        conn.flush()
        // Keep the response open: the export must reject the over-limit body
        // without waiting for the rest of it or for the response to finish.
        @async.sleep(5000)
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      timeout_millis=5000,
      max_retries=0,
    )
    let result = @otlp_async.export_spans(
      config,
      [test_span_data()],
      max_response_size=1,
    )
    match result {
      @sdk.ExportFailure(message) => assert_true(message.contains("1-byte"))
      @sdk.ExportSuccess => fail("expected a response size-limit failure")
    }
  }
}

///|
async test "response size limit accepts a body of exactly the limit" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        let _ = body.read_all()
        conn.send_response(200, "OK")
        conn.write(b"{}")
        conn.end_response()
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      protocol=@otlp.OTLP_HTTP_JSON_PROTOCOL,
    )
    let result = @otlp_async.export_spans(
      config,
      [test_span_data()],
      max_response_size=2,
    )
    assert_true(result.is_success())
  }
}

///|
async fn gzip_response_body(data : Bytes) -> Bytes {
  let reader = @io.MemoryReader() <| w => {
    let encoder = @gzip.Encoder(w)
    encoder.write(data)
    encoder.end()
  }
  defer reader.close()
  reader.read_all().binary()
}

///|
async test "response size limit applies after gzip decompression" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      let compressed = gzip_response_body(b"{}")
      let headers : @http.Headers = Map([
        (@http.CaseInsensitiveString("content-encoding"), "gzip"),
      ])
      server.run_forever() <| ((_request, body, conn) => {
        let _ = body.read_all()
        conn.send_response(200, "OK", extra_headers=headers)
        conn.write(compressed)
        conn.end_response()
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      protocol=@otlp.OTLP_HTTP_JSON_PROTOCOL,
    )
    let result = @otlp_async.export_spans(
      config,
      [test_span_data()],
      max_response_size=1,
    )
    match result {
      @sdk.ExportFailure(message) => assert_true(message.contains("1-byte"))
      @sdk.ExportSuccess => fail("expected a decompressed size-limit failure")
    }
  }
}
