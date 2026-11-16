// Regression test: `Accept-Encoding` is owned by the async transport. The
// HTTP client only enables automatic response decompression when it added that
// header itself, so forwarding a configured value would leave a gzip response
// body compressed and make the OTLP response decoder fail.

///|
async test "configured accept-encoding does not break response decompression" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let sent_accept_encoding : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      let compressed = gzip_response_body(b"{}")
      let response_headers : @http.Headers = Map([
        (@http.CaseInsensitiveString("content-encoding"), "gzip"),
      ])
      server.run_forever() <| ((request, body, conn) => {
        let _ = body.read_all()
        sent_accept_encoding.val = request.headers
          .get(@http.CaseInsensitiveString("accept-encoding"))
          .unwrap_or("")
        conn.send_response(200, "OK", extra_headers=response_headers)
        conn.write(compressed)
        conn.end_response()
      })
    }
    let configured : Map[String, String] = Map([], capacity=1)
    configured.set("Accept-Encoding", "gzip")
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      protocol=@otlp.OTLP_HTTP_JSON_PROTOCOL,
      headers=configured,
    )
    let result = @otlp_async.export_spans(config, [test_span_data()])
    assert_true(result.is_success())
    assert_eq(sent_accept_encoding.val, "gzip,identity")
  }
}
