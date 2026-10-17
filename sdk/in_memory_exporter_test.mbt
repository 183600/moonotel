// Tests for the in-memory span exporter.

test "in_memory_exporter_captures_exported_spans" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("mem-scope", version="1.0")
  let span = tracer.start_root_span("op")
  span.set_attribute("k", @sdk.StringValue("v"))
  span.end()
  assert_false(exporter.is_shutdown())
  assert_eq(exporter.span_count(), 1)
  let batches = exporter.exported_batches()
  assert_eq(batches.length(), 1)
  assert_eq(batches[0].length(), 1)
  let spans = exporter.exported_spans()
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].name, "op")
  assert_eq(spans[0].scope_name, "mem-scope")
  assert_eq(spans[0].scope_version, "1.0")
  assert_eq(
    spans[0].attributes.get("k"),
    Some(@sdk.StringValue("v")),
  )
}

test "in_memory_exporter_receives_only_sampled_spans" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem-drop")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_off())
  let tracer = provider.get_tracer("mem-scope")
  let span = tracer.start_root_span("dropped")
  span.end()
  assert_eq(exporter.span_count(), 0)
}

test "in_memory_exporter_take_and_clear" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem-take")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("mem-scope")
  for name in ["a", "b"] {
    tracer.start_root_span(name).end()
  }
  let taken = exporter.take_spans()
  assert_eq(taken.length(), 2)
  assert_eq(taken[0].name, "a")
  assert_eq(taken[1].name, "b")
  assert_eq(exporter.span_count(), 0)
  tracer.start_root_span("c").end()
  assert_eq(exporter.span_count(), 1)
  exporter.clear()
  assert_eq(exporter.span_count(), 0)
}

test "in_memory_exporter_empty_export_is_a_success" {
  let exporter = @sdk.InMemorySpanExporter::new()
  assert_eq(exporter.export_spans([]), @sdk.ExportSuccess)
  assert_eq(exporter.span_count(), 0)
}

test "in_memory_exporter_rejects_exports_after_shutdown" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem-shutdown")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("mem-scope")
  let captured = tracer.start_root_span("before")
  captured.end()
  let taken = exporter.take_spans()
  exporter.shutdown()
  assert_true(exporter.is_shutdown())
  let result = exporter.export_spans(taken)
  assert_false(result.is_success())
  assert_eq(exporter.span_count(), 0)
}

test "in_memory_exporter_returned_batches_are_copies" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem-copy")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  provider.get_tracer("mem-scope").start_root_span("one").end()
  let batches = exporter.exported_batches()
  batches[0].clear()
  assert_eq(exporter.span_count(), 1)
}
