// Integration tests for the async OTLP/HTTP exporter, driven against a real
// loopback `@http.Server`.

fn test_span_data() -> @sdk.SpanData {
  let trace_id = Array::make(16, 7)
  let span_id = Array::make(8, 9)
  let span_context = @api.span_context(trace_id, span_id, @api.TRACE_FLAGS_SAMPLED)
  {
    name: "otlp-async-test-op",
    span_context,
    parent_span_id: [],
    kind: @api.SpanKind::Client,
    start_time_unix_nano: 1000L,
    end_time_unix_nano: 2000L,
    attributes: Map([]),
    events: [],
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: Map([]),
    scope_name: "otlp-async-test",
    scope_version: "",
  }
}

async test "export_spans posts a protobuf body and accepts HTTP 200" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let received : Ref[Bytes] = Ref(b"")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        received.val = body.read_all().binary()
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    let result = export_spans(config, [test_span_data()])
    assert_true(result.is_success())
    assert_true(received.val.length() > 0)
  }
}

async test "export_spans of an empty batch succeeds without a request" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:1")
  let result = export_spans(config, [])
  assert_true(result.is_success())
}

async test "post_trace_request retries retryable statuses" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let requests : Ref[Int] = Ref(0)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        requests.val = requests.val + 1
        if requests.val < 3 {
          conn.send_response(503, "Service Unavailable")
        } else {
          conn.send_response(200, "OK")
        }
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      max_retries=3,
    )
    let result = export_spans(config, [test_span_data()])
    assert_true(result.is_success())
    assert_eq(requests.val, 3)
  }
}

async test "post_trace_request does not retry non-retryable statuses" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let requests : Ref[Int] = Ref(0)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        requests.val = requests.val + 1
        conn.send_response(400, "Bad Request")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      max_retries=3,
    )
    let result = export_spans(config, [test_span_data()])
    assert_false(result.is_success())
    assert_eq(requests.val, 1)
  }
}

async test "post_trace_request reports partial success as a failure" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(200, "OK")
        conn.write(b"\x0A\x02\x08\x03")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    let result = export_spans(config, [test_span_data()])
    assert_false(result.is_success())
  }
}

async test "post_trace_request fails when the endpoint is unreachable" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:1")
  let result = export_spans(config, [test_span_data()])
  assert_false(result.is_success())
}

async test "post_trace_request times out a collector that never responds" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        // Answer only well after the configured timeout, so that a missing
        // timeout shows up as an unexpected success instead of hanging.
        @async.sleep(5000)
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      timeout_millis=100,
      max_retries=0,
    )
    let result = export_spans(config, [test_span_data()])
    match result {
      @sdk.ExportFailure(message) =>
        assert_true(message.contains("TimeoutError"))
      @sdk.ExportSuccess => fail("expected the export to time out")
    }
  }
}

async test "request headers include the OTLP content type" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let observed : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        observed.val = request.headers
          .get(@http.CaseInsensitiveString("content-type"))
          .unwrap_or("")
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    let result = export_spans(config, [test_span_data()])
    assert_true(result.is_success())
    assert_eq(observed.val, "application/x-protobuf")
  }
}
