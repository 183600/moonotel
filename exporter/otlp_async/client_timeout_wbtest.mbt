// Whitebox coverage for the overall-deadline helpers and the retry backoff
// cap. The timeout clamp matters only for deadlines beyond the `Int32` range
// accepted by `@async.with_timeout`; the backoff cap keeps a large retry
// count from producing an unbounded delay.

///|
test "remaining_timeout_millis_clamps_expired_and_large_deadlines" {
  assert_eq(remaining_timeout_millis(0UL), 0)
  assert_eq(remaining_timeout_millis(0xFFFFFFFFFFFFFFFFUL), 2147483647)
}

///|
test "export_timeout_failure_includes_the_last_retryable_error" {
  match export_timeout_failure("") {
    @sdk.ExportFailure(message) => assert_eq(message, "OTLP export timed out")
    @sdk.ExportSuccess => fail("expected a timeout failure")
  }
  match export_timeout_failure("HTTP 503") {
    @sdk.ExportFailure(message) => {
      assert_true(message.contains("OTLP export timed out"))
      assert_true(message.contains("HTTP 503"))
    }
    @sdk.ExportSuccess => fail("expected a timeout failure")
  }
}

///|
test "retry_backoff_caps_positive_jitter_at_five_seconds" {
  // At attempt 21 the base has long reached 5000ms and the deterministic
  // jitter is positive, so the result must be clamped to the five-second cap.
  assert_eq(retry_backoff_millis(21), 5000)
}

///|
fn timeout_export_span() -> @sdk.SpanData {
  {
    name: "timeout",
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: [],
    parent_is_remote: None,
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map([]),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(Map([])),
    scope_name: "timeout",
    scope_version: "",
  }
}

///|
async test "timeout on the only attempt is reported as a timeout" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        let _ = body.read_all()
        @async.sleep(500)
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      timeout_millis=100,
      max_retries=0,
    )
    let exporter = OtlpHttpAsyncExporter::new(config)
    match exporter.export_batch([timeout_export_span()]) {
      @sdk.ExportFailure(message) =>
        assert_true(message.contains("OTLP export timed out"))
      @sdk.ExportSuccess => fail("expected a timeout failure")
    }
  }
}
