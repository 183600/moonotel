// Tests that the `SpanSdk` collection accessors return snapshots instead of
// the span's internal containers, so mutating the result cannot bypass the
// span limits or change the data that will be exported.

///|
fn accessor_test_span(name : String) -> @sdk.SpanSdk {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="accessor")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  provider.get_tracer("accessor").start_root_span(name)
}

///|
test "span_attributes_accessor_returns_a_snapshot" {
  let span = accessor_test_span("attrs")
  span.set_attribute("a", @sdk.StringValue("1"))
  let attributes = span.attributes()
  attributes.set("a", @sdk.StringValue("changed"))
  attributes.set("b", @sdk.StringValue("2"))
  assert_eq(span.attributes().length(), 1)
  assert_eq(span.attributes().get("a"), Some(@sdk.StringValue("1")))
  assert_true(span.attributes().get("b") is None)
}

///|
test "span_events_accessor_returns_a_snapshot" {
  let span = accessor_test_span("events")
  span.add_event("e0")
  let events = span.events()
  events.push({
    name: "injected",
    time_unix_nano: 0L,
    attributes: Map([]),
    dropped_attributes_count: 0,
  })
  events[0].attributes.set("k", @sdk.StringValue("v"))
  assert_eq(span.events().length(), 1)
  assert_eq(span.events()[0].name, "e0")
  assert_eq(span.events()[0].attributes.length(), 0)
}

///|
test "span_links_accessor_returns_a_snapshot" {
  let span = accessor_test_span("links")
  let context = @api.span_context(Array::make(16, 7), Array::make(8, 7), 1)
  span.add_link(@sdk.SpanLink::new(context))
  let links = span.links()
  links.push(@sdk.SpanLink::new(context))
  links[0].attributes.set("k", @sdk.StringValue("v"))
  assert_eq(span.links().length(), 1)
  assert_eq(span.links()[0].attributes.length(), 0)
}
