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
