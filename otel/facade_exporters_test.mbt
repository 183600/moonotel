// The facade re-exports the built-in test/debug exporters together with their
// constructors.

///|
test "facade_reexports_in_memory_exporter" {
  let exporter = @otel.InMemorySpanExporter::new()
  let provider = @otel.TracerProviderSdk::new(service_name="facade-mem")
    .with_span_processor(@otel.SimpleSpanProcessor::new(exporter))
    .with_sampler(@otel.Sampler::always_on())
  let tracer = provider.get_tracer("facade-mem")
  tracer.start_root_span("op").end()
  assert_eq(exporter.span_count(), 1)
  assert_eq(exporter.exported_spans()[0].name, "op")
}

///|
test "facade_reexports_console_exporter" {
  let exporter = @otel.ConsoleSpanExporter::new()
  assert_false(exporter.is_shutdown())
  exporter.shutdown()
  assert_true(exporter.is_shutdown())
}
