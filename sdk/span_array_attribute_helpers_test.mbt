// Tests for the array attribute setters on `SpanSdk`.

///|
test "array_attribute_helpers_record_values" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="typed-attrs-array")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("typed-attrs-array").start_root_span("op")
  span.set_string_array_attribute("sa", ["a", "b"])
  span.set_int_array_attribute("ia", [1L, -2L])
  span.set_bool_array_attribute("ba", [true, false])
  span.set_double_array_attribute("da", [1.5, 2.5])
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.get("sa"), Some(@sdk.StringArrayValue(["a", "b"])))
  assert_eq(data.attributes.get("ia"), Some(@sdk.IntArrayValue([1L, -2L])))
  assert_eq(data.attributes.get("ba"), Some(@sdk.BoolArrayValue([true, false])))
  assert_eq(data.attributes.get("da"), Some(@sdk.DoubleArrayValue([1.5, 2.5])))
}

///|
test "array_attribute_helpers_truncate_string_elements" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(
      service_name="typed-attrs-array-limit",
    )
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_limits(@sdk.SpanLimits::new(attribute_value_length_limit=3))
  let span = provider
    .get_tracer("typed-attrs-array-limit")
    .start_root_span("op")
  span.set_string_array_attribute("sa", ["abcdef", "xy"])
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(
    data.attributes.get("sa"),
    Some(@sdk.StringArrayValue(["abc", "xy"])),
  )
}

///|
test "array_attribute_helpers_are_noops_on_ended_spans" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(
      service_name="typed-attrs-array-late",
    )
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("typed-attrs-array-late").start_root_span("op")
  span.end()
  span.set_string_array_attribute("sa", ["late"])
  span.set_int_array_attribute("ia", [1L])
  span.set_bool_array_attribute("ba", [true])
  span.set_double_array_attribute("da", [1.0])
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.length(), 0)
}
