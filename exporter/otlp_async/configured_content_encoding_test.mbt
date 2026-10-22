// Regression test: an uncompressed async export must not forward a
// user-configured `Content-Encoding`, which would misdescribe the body.

///|
async test "configured_content_encoding_is_not_sent_without_compression" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let observed : Ref[String] = Ref("unset")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, body, conn) => {
        let _ = body.read_all()
        observed.val = request.headers
          .get(@http.CaseInsensitiveString("content-encoding"))
          .unwrap_or("")
        conn.send_response(200, "OK")
      })
    }
    let headers : Map[String, String] = Map([], capacity=1)
    headers.set("Content-Encoding", "gzip")
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      headers~,
    )
    let result = @otlp_async.export_spans(config, [test_span_data()])
    assert_true(result.is_success())
    assert_eq(observed.val, "")
  }
}
