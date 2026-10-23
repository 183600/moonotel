// Integration coverage for the URL handed to the real async HTTP client:
// fragments never reach the request target, uppercase schemes are accepted,
// and a network-path endpoint resolves against the default OTLP/HTTP scheme.

///|
async test "async exporter normalizes the request URL" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let paths : Ref[Array[String]] = Ref([])
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, body, conn) => {
        let _ = body.read_all()
        paths.val.push(request.path)
        conn.send_response(200, "OK")
      })
    }
    let fragment = @otlp.OtlpHttpConfig::new(
      traces_endpoint="http://127.0.0.1:\{port}/fragment#frag",
    )
    assert_true(
      @otlp_async.export_spans(fragment, [test_span_data()]).is_success(),
    )
    let uppercase = @otlp.OtlpHttpConfig::new(
      traces_endpoint="HTTP://127.0.0.1:\{port}/uppercase",
    )
    assert_true(
      @otlp_async.export_spans(uppercase, [test_span_data()]).is_success(),
    )
    let network_path = @otlp.OtlpHttpConfig::new(
      traces_endpoint="//127.0.0.1:\{port}/network-path",
    )
    assert_true(
      @otlp_async.export_spans(network_path, [test_span_data()]).is_success(),
    )
    assert_eq(paths.val, ["/fragment", "/uppercase", "/network-path"])
  }
}
