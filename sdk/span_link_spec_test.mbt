// Blackbox tests for the specification rule that links with an invalid
// SpanContext are still recorded when they carry attributes or a non-empty
// tracestate.

///|
fn link_spec_exporter() -> @sdk.InMemorySpanExporter {
  @sdk.InMemorySpanExporter::new()
}

///|
fn link_spec_tracer(
  exporter : @sdk.InMemorySpanExporter,
) -> @sdk.Tracer {
  @sdk.TracerProviderSdk::new(service_name="svc")
  .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  .with_sampler(@sdk.Sampler::always_on())
  .get_tracer("links")
}

///|
fn invalid_context_with_tracestate() -> @api.SpanContext {
  @api.span_context([], [], 0, tracestate="vendor=value")
}

///|
test "add_link_records_invalid_context_link_with_attributes" {
  let exporter = link_spec_exporter()
  let tracer = link_spec_tracer(exporter)
  let span = tracer.start_span("op")
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("link.reason", @sdk.StringValue("retry"))
  span.add_link(@sdk.SpanLink::new(@api.invalid_span_context(), attributes~))
  assert_eq(span.links().length(), 1)
  span.end()
  assert_eq(exporter.span_count(), 1)
  assert_eq(exporter.exported_spans()[0].links.length(), 1)
}

///|
test "add_link_records_invalid_context_link_with_tracestate" {
  let exporter = link_spec_exporter()
  let tracer = link_spec_tracer(exporter)
  let span = tracer.start_span("op")
  span.add_link(@sdk.SpanLink::new(invalid_context_with_tracestate()))
  assert_eq(span.links().length(), 1)
  span.end()
  assert_eq(exporter.exported_spans()[0].links.length(), 1)
}

///|
test "add_link_drops_invalid_context_link_without_attributes_or_tracestate" {
  let exporter = link_spec_exporter()
  let tracer = link_spec_tracer(exporter)
  let span = tracer.start_span("op")
  span.add_link(@sdk.SpanLink::new(@api.invalid_span_context()))
  assert_eq(span.links().length(), 0)
  span.end()
  assert_eq(exporter.exported_spans()[0].links.length(), 0)
}

///|
test "start_span_records_invalid_context_link_with_attributes" {
  let exporter = link_spec_exporter()
  let tracer = link_spec_tracer(exporter)
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("link.kind", @sdk.StringValue("follows"))
  let span = tracer.start_span("op", links=[
    @sdk.SpanLink::new(@api.invalid_span_context(), attributes~),
  ])
  span.end()
  assert_eq(exporter.exported_spans()[0].links.length(), 1)
  assert_eq(
    exporter.exported_spans()[0].links[0].attributes.get("link.kind"),
    Some(@sdk.StringValue("follows")),
  )
}
