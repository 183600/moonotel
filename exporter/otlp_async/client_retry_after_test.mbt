// Tests for `Retry-After` handling in the async OTLP/HTTP exporter.

async test "post_trace_request honors the Retry-After header" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let requests : Ref[Int32] = Ref(0)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        requests.val = requests.val + 1
        if requests.val < 2 {
          let headers : @http.Headers = Map([
            (@http.CaseInsensitiveString("retry-after"), "0"),
          ])
          conn.send_response(503, "Service Unavailable", extra_headers=headers)
        } else {
          conn.send_response(200, "OK")
        }
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      max_retries=1,
    )
    let result = @otlp_async.export_spans(config, [test_span_data()])
    assert_true(result.is_success())
    assert_eq(requests.val, 2)
  }
}

async test "post_trace_request ignores a malformed Retry-After header" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let requests : Ref[Int32] = Ref(0)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        requests.val = requests.val + 1
        if requests.val < 2 {
          let headers : @http.Headers = Map([
            (@http.CaseInsensitiveString("retry-after"), "not-a-delay"),
          ])
          conn.send_response(503, "Service Unavailable", extra_headers=headers)
        } else {
          conn.send_response(200, "OK")
        }
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      max_retries=1,
    )
    let result = @otlp_async.export_spans(config, [test_span_data()])
    assert_true(result.is_success())
    assert_eq(requests.val, 2)
  }
}
