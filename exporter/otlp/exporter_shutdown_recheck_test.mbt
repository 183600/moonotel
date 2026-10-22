// A shutdown performed during an export attempt (for example by a transport
// wrapper) stops the retry loop before another request is sent.

///|
test "retry_loop_stops_after_reentrant_shutdown" {
  let holder : Ref[@otlp.OtlpHttpExporter?] = Ref(None)
  let calls : Ref[Int32] = Ref(0)
  let transport : @otlp.Transport = fn(_url, _headers, _body) {
    calls.val = calls.val + 1
    match holder.val {
      Some(exporter) => exporter.shutdown()
      None => ()
    }
    { status_code: 503, body: b"", }
  }
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(
      endpoint="http://collector:4318",
      max_retries=3,
    ),
    transport,
  )
  holder.val = Some(exporter)
  let result = exporter.export_spans([test_span()])
  assert_false(result.is_success())
  assert_eq(calls.val, 1)
  assert_true(exporter.is_shutdown())
}
