// Export failure accounting and the single-span exporter path: processors
// count failed exports instead of retrying silently, and an exporter that was
// shut down rejects the single-span convenience entry point as well.

///|
struct FailingExportCounter {
  mut calls : Int32
}

///|
pub impl @sdk.SpanExporter for FailingExportCounter with fn export_spans(
  self,
  spans,
) {
  self.calls = self.calls + spans.length()
  @sdk.ExportFailure("collector unavailable")
}

///|
pub impl @sdk.SpanExporter for FailingExportCounter with fn shutdown(self) {
  let _ = self
}

///|
fn failure_test_span(name : String) -> @sdk.SpanData {
  {
    name,
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      @api.TRACE_FLAGS_SAMPLED,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map([], capacity=1),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(Map([], capacity=1)),
    scope_name: "failure-test",
    scope_version: "",
  }
}

///|
test "simple_span_processor_counts_failed_exports" {
  let exporter : FailingExportCounter = { calls: 0 }
  let processor = @sdk.SimpleSpanProcessor::new(exporter)
  processor.on_end(failure_test_span("first"))
  assert_eq(exporter.calls, 1)
  assert_eq(processor.export_failures(), 1UL)
  processor.on_end(failure_test_span("second"))
  assert_eq(processor.export_failures(), 2UL)
  // A shut-down processor no longer calls the exporter.
  processor.shutdown()
  assert_true(processor.is_shutdown())
  processor.on_end(failure_test_span("ignored"))
  assert_eq(exporter.calls, 2)
  assert_eq(processor.export_failures(), 2UL)
}

///|
test "batch_span_processor_counts_failed_exports" {
  let exporter : FailingExportCounter = { calls: 0 }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=4,
    max_export_batch_size=1,
    flush_interval_millis=0,
  )
  processor.on_end(failure_test_span("first"))
  assert_eq(exporter.calls, 1)
  assert_eq(processor.export_failures(), 1UL)
  assert_eq(processor.queue_size(), 0)
  processor.on_end(failure_test_span("second"))
  processor.force_flush()
  assert_eq(exporter.calls, 2)
  assert_eq(processor.export_failures(), 2UL)
  assert_eq(processor.queue_size(), 0)
}

///|
test "in_memory_exporter_rejects_a_single_span_after_shutdown" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let data = failure_test_span("stored")
  assert_true(exporter.export_span(data).is_success())
  assert_eq(exporter.span_count(), 1)
  exporter.shutdown()
  let result = exporter.export_span(failure_test_span("rejected"))
  assert_false(result.is_success())
  assert_eq(exporter.span_count(), 1)
}
