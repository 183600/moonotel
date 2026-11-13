// Tests for `Retry-After` handling in the async OTLP/HTTP exporter.

///|
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

///|
async test "post_trace_request honors an HTTP-date Retry-After header" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let requests : Ref[Int32] = Ref(0)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        requests.val = requests.val + 1
        if requests.val < 2 {
          let headers : @http.Headers = Map([
            (
              @http.CaseInsensitiveString("retry-after"),
              // An IMF-fixdate in the past: retry immediately.
              "Sun, 06 Nov 1994 08:49:37 GMT",
            ),
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

///|
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

///|
async test "post_trace_request shortens Retry-After to the remaining budget" {
  // A long Retry-After must not extend the overall export budget: the wait is
  // shortened to whatever time is left, and the next iteration reports the
  // timeout without issuing another request.
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let requests : Ref[Int32] = Ref(0)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        requests.val = requests.val + 1
        let headers : @http.Headers = Map([
          (@http.CaseInsensitiveString("retry-after"), "60"),
        ])
        conn.send_response(503, "Service Unavailable", extra_headers=headers)
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      timeout_millis=100,
      max_retries=3,
    )
    let result = @otlp_async.export_spans(config, [test_span_data()])
    match result {
      @sdk.ExportFailure(message) => assert_true(message.contains("timed out"))
      @sdk.ExportSuccess => fail("expected the overall export timeout")
    }
    assert_eq(requests.val, 1)
  }
}

///|
async test "post_trace_request retries when the timeout is disabled" {
  // `timeout_millis = 0` explicitly disables the overall deadline. Retries
  // must still happen and use the normal exponential backoff instead of being
  // skipped because there is no deadline to wait against.
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
      timeout_millis=0,
      max_retries=1,
    )
    let result = @otlp_async.export_spans(config, [test_span_data()])
    assert_true(result.is_success())
    assert_eq(requests.val, 2)
  }
}
