// Boundary coverage for processor construction, ring-buffer reuse, empty
// flushes and the console exporter's batch/single-span entry points.

///|
struct EdgeExporter {
  names : Array[String]
}

///|
pub impl @sdk.SpanExporter for EdgeExporter with fn export_spans(self, spans) {
  for data in spans {
    self.names.push(data.name)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for EdgeExporter with fn shutdown(self) {
  let _ = self
}

///|
fn edge_span(name : String) -> @sdk.SpanData {
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
    scope_name: "edge",
    scope_version: "",
  }
}

///|
fn edge_names(exporter : EdgeExporter) -> Array[String] {
  exporter.names.copy()
}

///|
test "batch_processor_clamps_invalid_construction_values" {
  let exporter : EdgeExporter = { names: [] }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=0,
    max_export_batch_size=0,
    flush_interval_millis=-5,
  )
  // Both sizes are clamped to 1 and the negative interval to 0 (timed flushes
  // disabled). A single span therefore fills the batch and is exported at once.
  assert_eq(processor.flush_interval_millis(), 0)
  assert_eq(processor.queue_size(), 0)
  processor.on_end(edge_span("clamped"))
  assert_eq(processor.queue_size(), 0)
  assert_eq(edge_names(exporter), ["clamped"])
  assert_eq(processor.dropped_spans(), 0UL)
}

///|
test "batch_processor_flush_batch_is_a_noop_on_an_empty_queue" {
  let exporter : EdgeExporter = { names: [] }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=2,
    max_export_batch_size=2,
    flush_interval_millis=0,
  )
  processor.flush_batch()
  processor.force_flush()
  assert_eq(exporter.names.length(), 0)
  assert_eq(processor.queue_size(), 0)
  assert_eq(processor.export_failures(), 0UL)
}

///|
test "batch_processor_reuses_ring_buffer_slots_after_flushes" {
  let exporter : EdgeExporter = { names: [] }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=2,
    max_export_batch_size=1,
    flush_interval_millis=0,
  )
  // Each span forms its own batch, so the head wraps and the second pass reuses
  // a cleared slot instead of growing the backing array again.
  processor.on_end(edge_span("s0"))
  processor.on_end(edge_span("s1"))
  processor.on_end(edge_span("s2"))
  processor.force_flush()
  assert_eq(edge_names(exporter), ["s0", "s1", "s2"])
  assert_eq(processor.queue_size(), 0)
  assert_eq(processor.dropped_spans(), 0UL)
}

///|
test "console_exporter_exports_batches_and_rejects_after_shutdown" {
  let exporter = @sdk.ConsoleSpanExporter::new()
  assert_eq(
    exporter.export_spans([edge_span("console-a"), edge_span("console-b")]),
    @sdk.ExportSuccess,
  )
  assert_eq(exporter.export_span(edge_span("console-c")), @sdk.ExportSuccess)
  assert_false(exporter.is_shutdown())
  exporter.shutdown()
  assert_true(exporter.is_shutdown())
  match exporter.export_spans([]) {
    @sdk.ExportFailure(message) =>
      assert_true(message.contains("shut down"))
    @sdk.ExportSuccess => fail("expected a failure after shutdown")
  }
  match exporter.export_span(edge_span("console-d")) {
    @sdk.ExportFailure(message) =>
      assert_true(message.contains("shut down"))
    @sdk.ExportSuccess => fail("expected a failure after shutdown")
  }
}
