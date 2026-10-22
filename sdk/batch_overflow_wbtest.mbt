// White-box tests for the batch queue's defensive overflow path. With the
// export batch capped at the queue size, normal `on_end` traffic flushes before
// the queue can fill; `push_span` is used directly to exercise the documented
// oldest-span-overwrite behavior.

///|
fn overflow_probe_span(name : String) -> SpanData {
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
    attributes: Map([]),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: ResourceAttributes::new(Map([])),
    scope_name: "batch-overflow",
    scope_version: "",
  }
}

///|
fn overflow_probe_names(spans : Array[SpanData]) -> Array[String] {
  let names : Array[String] = []
  for span in spans {
    names.push(span.name)
  }
  names
}

///|
test "overflow_overwrites_the_oldest_buffered_span" {
  let exporter = InMemorySpanExporter::new()
  let processor = BatchSpanProcessor::new(
    exporter,
    max_queue_size=2,
    max_export_batch_size=2,
    flush_interval_millis=0,
  )
  processor.push_span(overflow_probe_span("s0"))
  processor.push_span(overflow_probe_span("s1"))
  processor.push_span(overflow_probe_span("s2"))
  assert_eq(processor.queue_size(), 2)
  assert_eq(processor.dropped_spans(), 1UL)
  processor.force_flush()
  assert_eq(processor.queue_size(), 0)
  assert_eq(
    overflow_probe_names(exporter.exported_spans()),
    ["s1", "s2"],
  )
}

///|
test "overflow_wraps_the_ring_after_a_partial_flush" {
  let exporter = InMemorySpanExporter::new()
  let processor = BatchSpanProcessor::new(
    exporter,
    max_queue_size=2,
    max_export_batch_size=2,
    flush_interval_millis=0,
  )
  processor.push_span(overflow_probe_span("s0"))
  processor.push_span(overflow_probe_span("s1"))
  processor.flush_batch()
  assert_eq(processor.queue_size(), 0)
  processor.push_span(overflow_probe_span("s2"))
  processor.push_span(overflow_probe_span("s3"))
  processor.push_span(overflow_probe_span("s4"))
  assert_eq(processor.queue_size(), 2)
  assert_eq(processor.dropped_spans(), 1UL)
  processor.force_flush()
  assert_eq(
    overflow_probe_names(exporter.exported_spans()),
    ["s0", "s1", "s3", "s4"],
  )
}
