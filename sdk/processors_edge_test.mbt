// Edge paths of the span processors and of string attribute truncation.

///|
struct ProcessorEdgeExporter {
  exported : Ref[Array[String]]
  shutdowns : Ref[Int32]
}

///|
pub impl @sdk.SpanExporter for ProcessorEdgeExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.exported.val.push(data.name)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for ProcessorEdgeExporter with fn shutdown(self) {
  self.shutdowns.val = self.shutdowns.val + 1
}

///|
fn processor_edge_exporter() -> ProcessorEdgeExporter {
  { exported: Ref([]), shutdowns: Ref(0), }
}

///|
test "simple_processor_force_flush_is_a_noop" {
  let exporter = processor_edge_exporter()
  let processor = @sdk.SimpleSpanProcessor::new(exporter)
  processor.force_flush()
  assert_false(processor.is_shutdown())
  assert_eq(exporter.exported.val.length(), 0)
  assert_eq(exporter.shutdowns.val, 0)
}

///|
test "batch_processor_tick_on_empty_queue_is_a_noop" {
  let exporter = processor_edge_exporter()
  let processor = @sdk.BatchSpanProcessor::new(exporter)
  processor.tick()
  processor.force_flush()
  assert_eq(exporter.exported.val.length(), 0)
  assert_eq(exporter.shutdowns.val, 0)
}

///|
test "batch_processor_drops_spans_after_shutdown" {
  let exporter = processor_edge_exporter()
  let processor = @sdk.BatchSpanProcessor::new(exporter)
  processor.shutdown()
  assert_true(processor.is_shutdown())
  let provider = @sdk.TracerProviderSdk::new(service_name="edge-processor").with_span_processor(
    processor,
  )
  let tracer = provider.get_tracer("edge-processor")
  let span = tracer.start_root_span("late")
  span.end()
  processor.force_flush()
  assert_eq(exporter.exported.val.length(), 0)
  assert_eq(exporter.shutdowns.val, 1)
}

///|
test "span_limits_accessor_returns_the_provider_limits" {
  let limits = @sdk.SpanLimits::new(attribute_count_limit=7)
  let provider = @sdk.TracerProviderSdk::new(service_name="limits-accessor").with_span_limits(
    limits,
  )
  let tracer = provider.get_tracer("limits-accessor")
  let span = tracer.start_root_span("op")
  assert_eq(span.limits().attribute_count_limit(), 7)
  span.end()
}
