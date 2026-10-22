// The public `BatchSpanProcessor::flush_batch` entry point exports at most one
// batch and becomes a no-op once the processor has been shut down.

///|
test "flush_batch exports the buffered spans" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=8,
    max_export_batch_size=4,
    flush_interval_millis=0,
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="flush-batch")
    .with_span_processor(processor)
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("flush-batch")
  tracer.start_root_span("one").end()
  tracer.start_root_span("two").end()
  assert_eq(processor.queue_size(), 2)
  assert_eq(exporter.span_count(), 0)
  processor.flush_batch()
  assert_eq(processor.queue_size(), 0)
  assert_eq(exporter.span_count(), 2)
  assert_eq(exporter.exported_spans()[0].name, "one")
  assert_eq(exporter.exported_spans()[1].name, "two")
  provider.shutdown()
}

///|
test "flush_batch does not export after shutdown" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=8,
    max_export_batch_size=8,
    flush_interval_millis=0,
  )
  processor.shutdown()
  assert_true(processor.is_shutdown())
  processor.flush_batch()
  assert_eq(exporter.span_count(), 0)
  assert_eq(processor.queue_size(), 0)
}
