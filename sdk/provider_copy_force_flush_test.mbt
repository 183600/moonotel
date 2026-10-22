// A processor added to a copy of a provider starts out unshut-down. Even when
// the shared provider shutdown marker is already set by another copy, forcing
// a flush on the copy must reach that still-open processor.

///|
test "force_flush_reaches_a_processor_added_to_a_shut_down_copy" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let batch : &@sdk.SpanProcessor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=16,
    max_export_batch_size=16,
    flush_interval_millis=1000000,
  )
  let base = @sdk.TracerProviderSdk::new(service_name="copy-flush")
    .with_sampler(@sdk.Sampler::always_on())
  let copy = base.with_span_processor(batch)
  copy.get_tracer("copy-flush").start_root_span("queued").end()
  assert_eq(exporter.span_count(), 0)
  base.shutdown()
  assert_true(copy.is_shutdown())
  // Shutting down `base` does not own the copy's processor; shutting `copy`
  // would drain it, but a force flush must also be able to recover it.
  assert_false(exporter.is_shutdown())
  copy.force_flush()
  assert_eq(exporter.span_count(), 1)
  copy.shutdown()
  assert_true(exporter.is_shutdown())
}
