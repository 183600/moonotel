// Tests for the console span exporter. The printed lines are not asserted
// (the test runner may capture them); the exporter's contract is.

///|
test "console_exporter_exports_and_tracks_shutdown" {
  let exporter = @sdk.ConsoleSpanExporter::new()
  assert_false(exporter.is_shutdown())
  let provider = @sdk.TracerProviderSdk::new(service_name="console")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("console-scope")
  let span = tracer.start_root_span("printed", kind=@api.SpanKind::Server)
  span.add_event("started")
  span.end()
  assert_false(exporter.is_shutdown())
  exporter.shutdown()
  assert_true(exporter.is_shutdown())
}

///|
test "console_exporter_rejects_exports_after_shutdown" {
  let exporter = @sdk.ConsoleSpanExporter::new()
  exporter.shutdown()
  assert_false(exporter.export_spans([]).is_success())
}

///|
test "console_exporter_empty_export_succeeds_before_shutdown" {
  let exporter = @sdk.ConsoleSpanExporter::new()
  assert_eq(exporter.export_spans([]), @sdk.ExportSuccess)
}
