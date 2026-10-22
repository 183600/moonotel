// Value-length truncation must never leave half of a surrogate pair at the
// cut. A complete pair is kept together; an unpaired low surrogate at the cut
// is dropped rather than exported as invalid UTF-16.

///|
test "attribute_truncation_drops_an_unpaired_low_surrogate" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="surrogate-truncation")
    .with_span_limits(@sdk.SpanLimits::new(attribute_value_length_limit=2))
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("surrogate-truncation")
  let high = (0xD83D).unsafe_to_char()
  let low = (0xDE00).unsafe_to_char()
  let lone_low = String::from_array(['a', low, 'b'])
  let pair = String::from_array([high, low])
  let span = tracer.start_root_span("op")
  span.set_attribute("lone", @sdk.StringValue(lone_low))
  span.set_attribute("pair", @sdk.StringValue("a" + pair))
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.get("lone"), Some(@sdk.StringValue("a")))
  assert_eq(data.attributes.get("pair"), Some(@sdk.StringValue("a" + pair)))
}
