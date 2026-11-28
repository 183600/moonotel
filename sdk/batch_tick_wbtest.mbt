// Whitebox regression test for timed flushes when the wall clock moves
// backwards. `last_flush_time_millis` is private, so the test sets it directly.

///|
fn tick_probe_span(name : String) -> SpanData {
  let trace_id : Array[Int32] = Array::make(16, 7)
  let span_id : Array[Int32] = Array::make(8, 7)
  {
    name,
    span_context: @api.span_context(trace_id, span_id, @api.TRACE_FLAGS_SAMPLED),
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
    resource: ResourceAttributes::new(Map([])),
    scope_name: "tick-probe",
    scope_version: "",
  }
}

///|
test "tick does not flush when the last flush time is in the future" {
  let exporter = InMemorySpanExporter::new()
  let processor = BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=10,
    flush_interval_millis=60000,
  )
  processor.on_end(tick_probe_span("s0"))
  assert_eq(processor.queue_size(), 1)
  processor.last_flush_time_millis = @env.now() + 1000000UL
  processor.tick()
  assert_eq(processor.queue_size(), 1)
  assert_eq(exporter.span_count(), 0)
}

///|
test "timed_flush_exports_one_batch_at_a_time" {
  let exporter = InMemorySpanExporter::new()
  let processor = BatchSpanProcessor::new(
    exporter,
    max_queue_size=8,
    max_export_batch_size=2,
    flush_interval_millis=60000,
  )
  // Queue directly so the batch-full path does not fire before `tick`.
  for index = 0; index < 5; index = index + 1 {
    processor.push_span(tick_probe_span("s\{index}"))
  }
  assert_eq(processor.queue_size(), 5)
  // Pretend the scheduled interval elapsed, then run the timed flush.
  processor.last_flush_time_millis = 0UL
  processor.tick()
  assert_eq(processor.queue_size(), 3)
  assert_eq(exporter.span_count(), 2)
  processor.last_flush_time_millis = 0UL
  processor.tick()
  assert_eq(processor.queue_size(), 1)
  assert_eq(exporter.span_count(), 4)
  processor.last_flush_time_millis = 0UL
  processor.tick()
  assert_eq(processor.queue_size(), 0)
  assert_eq(exporter.span_count(), 5)
}
