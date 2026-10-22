// A provider drains every batch processor before shutting any processor down,
// so processors that share an exporter cannot lose queued spans when an
// earlier shutdown closes that exporter.

///|
test "shutdown_drains_batch_before_a_simple_processor_closes_the_exporter" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let simple : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let batch : &@sdk.SpanProcessor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=100,
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="shared-exporter")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_processor(simple)
    .with_span_processor(batch)
  let tracer = provider.get_tracer("shared-exporter")
  tracer.start_root_span("immediate").end()
  tracer.start_root_span("queued").end()
  // The simple processor exported both spans immediately; the batch processor
  // still holds both.
  assert_eq(exporter.span_count(), 2)
  provider.shutdown()
  // Both processors deliver both spans, and none is lost to the earlier
  // exporter shutdown.
  assert_eq(exporter.span_count(), 4)
  assert_true(exporter.is_shutdown())
}

///|
test "shutdown_drains_all_batch_processors_sharing_an_exporter" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let first : &@sdk.SpanProcessor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=100,
  )
  let second : &@sdk.SpanProcessor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=100,
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="two-batches")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_processor(first)
    .with_span_processor(second)
  let tracer = provider.get_tracer("two-batches")
  tracer.start_root_span("first").end()
  tracer.start_root_span("second").end()
  assert_eq(exporter.span_count(), 0)
  provider.shutdown()
  // Each batch processor holds both spans, and both are drained before the
  // shared exporter is shut down.
  assert_eq(exporter.span_count(), 4)
}

///|
test "shutdown_drains_batches_nested_in_a_multi_processor" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let simple : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let batch : &@sdk.SpanProcessor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=100,
  )
  let multi = @sdk.MultiSpanProcessor::new(processors=[batch])
  let provider = @sdk.TracerProviderSdk::new(service_name="nested")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_processor(simple)
    .with_span_processor(multi)
  let tracer = provider.get_tracer("nested")
  tracer.start_root_span("immediate").end()
  tracer.start_root_span("queued").end()
  assert_eq(exporter.span_count(), 2)
  provider.shutdown()
  assert_eq(exporter.span_count(), 4)
}
