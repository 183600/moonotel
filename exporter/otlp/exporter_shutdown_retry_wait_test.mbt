// A shutdown performed by the retry-wait strategy also stops the retry loop
// before the next request is sent.

///|
test "retry_wait_can_stop_the_retry_loop_by_shutting_down" {
  let holder : Ref[@otlp.OtlpHttpExporter?] = Ref(None)
  let calls : Ref[Int32] = Ref(0)
  let transport : @otlp.Transport = fn(_url, _headers, _body) {
    calls.val = calls.val + 1
    { status_code: 503, body: b"", }
  }
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(
      endpoint="http://collector:4318",
      max_retries=3,
    ),
    transport,
    retry_wait=fn(_attempt) {
      match holder.val {
        Some(value) => value.shutdown()
        None => ()
      }
    },
  )
  holder.val = Some(exporter)
  let result = exporter.export_spans([test_span()])
  assert_false(result.is_success())
  assert_eq(calls.val, 1)
  assert_true(exporter.is_shutdown())
}
