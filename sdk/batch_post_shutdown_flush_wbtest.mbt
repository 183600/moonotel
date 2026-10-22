// A shut-down batch processor must not export again, even when a flush is
// requested directly. `shutdown` drains the queue first; `force_flush` and
// `flush_batch` are no-ops afterwards so a closed exporter is never reused.

///|
struct PostShutdownFlushExporter {
  exports : Ref[Int32]
}

///|
pub impl SpanExporter for PostShutdownFlushExporter with fn export_spans(
  self,
  spans,
) {
  self.exports.val = self.exports.val + spans.length()
  ExportSuccess
}

///|
pub impl SpanExporter for PostShutdownFlushExporter with fn shutdown(self) {
  let _ = self
}

///|
pub extend PostShutdownFlushExporter with SpanExporter::{
  export_spans,
  export_span,
  shutdown,
}

///|
fn post_shutdown_flush_span(name : String) -> SpanData {
  {
    name,
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: [],
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
    resource: ResourceAttributes::new(Map([])),
    scope_name: "post-shutdown-flush",
    scope_version: "",
  }
}

///|
test "force_flush and flush_batch do not export after shutdown" {
  let exporter : PostShutdownFlushExporter = { exports: Ref(0), }
  let processor = BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=10,
    flush_interval_millis=0,
  )
  processor.shutdown()
  assert_true(processor.is_shutdown())
  // Simulate a span that was still being accepted at the shutdown boundary;
  // the queue must not make a post-shutdown flush reach the closed exporter.
  processor.push_span(post_shutdown_flush_span("late"))
  processor.force_flush()
  processor.flush_batch()
  assert_eq(exporter.exports.val, 0)
  assert_eq(processor.queue_size(), 1)
}
