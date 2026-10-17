// Tests for the typed attribute setters on `SpanSdk`.

test "typed_attribute_helpers_record_values" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="typed-attrs")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("typed-attrs").start_root_span("op")
  span.set_string_attribute("s", "text")
  span.set_bool_attribute("b", true)
  span.set_int_attribute("i", 42L)
  span.set_double_attribute("d", 1.5)
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.get("s"), Some(@sdk.StringValue("text")))
  assert_eq(data.attributes.get("b"), Some(@sdk.BoolValue(true)))
  assert_eq(data.attributes.get("i"), Some(@sdk.IntValue(42L)))
  assert_eq(data.attributes.get("d"), Some(@sdk.DoubleValue(1.5)))
}

test "typed_attribute_helpers_are_noops_on_ended_spans" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="typed-attrs-late")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("typed-attrs").start_root_span("op")
  span.end()
  span.set_string_attribute("s", "late")
  span.set_bool_attribute("b", false)
  span.set_int_attribute("i", 1L)
  span.set_double_attribute("d", 0.0)
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.length(), 0)
}

test "typed_attribute_helpers_obey_value_length_limits" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="typed-attrs-limit")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_limits(@sdk.SpanLimits::new(attribute_value_length_limit=3))
  let span = provider.get_tracer("typed-attrs").start_root_span("op")
  span.set_string_attribute("s", "abcdef")
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.get("s"), Some(@sdk.StringValue("abc")))
}

test "typed_attribute_helpers_are_noops_for_non_recording_spans" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="typed-attrs-off")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_off())
  let span = provider.get_tracer("typed-attrs").start_root_span("op")
  assert_false(span.is_recording())
  span.set_string_attribute("s", "text")
  span.set_int_attribute("i", 1L)
  span.end()
  assert_eq(exporter.span_count(), 0)
}
