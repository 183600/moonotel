// Tests for gzip-compressed OTLP/HTTP export.

///|
async fn gunzip(data : Bytes) -> Bytes {
  let reader = @io.MemoryReader() <| w => { w.write(data) }
  defer reader.close()
  @gzip.Decoder(reader).read_all().binary()
}

///|
async test "export_spans sends a gzipped body with content-encoding" {
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
    let spans = [test_span_data()]
    let result = export_spans(config, spans)
    assert_true(result.is_success())
    assert_eq(encoding.val, "gzip")
    let decoded = gunzip(received.val)
    assert_eq(decoded, @otlp.encode_trace_request(spans))
  }
}

///|
async test "export_spans sends an uncompressed body by default" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let encoding : Ref[String] = Ref("unset")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, body, conn) => {
        let _ = body.read_all()
        encoding.val = request.headers
          .get(@http.CaseInsensitiveString("content-encoding"))
          .unwrap_or("")
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    let result = export_spans(config, [test_span_data()])
    assert_true(result.is_success())
    assert_eq(encoding.val, "")
  }
}

///|
async test "post_trace_request rejects unsupported compression" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://127.0.0.1:1",
    compression="zstd",
  )
  let result = export_spans(config, [test_span_data()])
  match result {
    @sdk.ExportFailure(message) => assert_true(message.contains("compression"))
    @sdk.ExportSuccess => fail("expected unsupported compression to fail")
  }
}

///|
test "from_env reads and trims gzip compression" {
  @env.set_env_var("OTEL_EXPORTER_OTLP_COMPRESSION", " gzip ")
  let config = @otlp.OtlpHttpConfig::from_env()
  @env.unset_env_var("OTEL_EXPORTER_OTLP_COMPRESSION")
  assert_eq(config.compression, "gzip")
}

///|
test "from_env treats an empty compression value as none" {
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_COMPRESSION", "")
  let config = @otlp.OtlpHttpConfig::from_env()
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_COMPRESSION")
  assert_eq(config.compression, "none")
}
