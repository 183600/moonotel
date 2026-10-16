// Blackbox tests for span links.

///|
struct LinkRecordingExporter {
  spans : Array[@sdk.SpanData]
}

///|
pub impl @sdk.SpanExporter for LinkRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for span in spans {
    self.spans.push(span)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for LinkRecordingExporter with fn shutdown(self) {
  let _ = self
}

///|
fn link_test_tracer(
  sampler : @sdk.Sampler,
) -> (@sdk.Tracer, LinkRecordingExporter) {
  let exporter : LinkRecordingExporter = { spans: [], }
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(sampler)
  (provider.get_tracer("links"), exporter)
}

///|
fn link_context(seed : Int32) -> @api.SpanContext {
  @api.span_context(
    Array::make(16, seed),
    Array::make(8, seed + 1),
    @api.TRACE_FLAGS_SAMPLED,
  )
}

///|
test "start_span records links with attributes" {
  let (tracer, exporter) = link_test_tracer(@sdk.Sampler::always_on())
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("link.reason", @sdk.StringValue("retry"))
  let span = tracer.start_span("op", links=[
    @sdk.SpanLink::new(link_context(3), attributes~),
  ])
  assert_eq(span.links().length(), 1)
  span.end()
  let data = exporter.spans[0]
  assert_eq(data.links.length(), 1)
  assert_eq(
    data.links[0].span_context.trace_id_hex(),
    link_context(3).trace_id_hex(),
  )
  assert_eq(
    data.links[0].span_context.span_id_hex(),
    link_context(3).span_id_hex(),
  )
  assert_eq(
    data.links[0].attributes.get("link.reason"),
    Some(@sdk.StringValue("retry")),
  )
}

///|
test "start_span drops links with an invalid span context" {
  let (tracer, exporter) = link_test_tracer(@sdk.Sampler::always_on())
  let span = tracer.start_span("op", links=[
    @sdk.SpanLink::new(@api.invalid_span_context()),
    @sdk.SpanLink::new(link_context(4)),
  ])
  span.end()
  let data = exporter.spans[0]
  assert_eq(data.links.length(), 1)
  assert_eq(
    data.links[0].span_context.trace_id_hex(),
    link_context(4).trace_id_hex(),
  )
}

///|
test "add_link appends a valid link" {
  let (tracer, exporter) = link_test_tracer(@sdk.Sampler::always_on())
  let span = tracer.start_span("op")
  span.add_link(@sdk.SpanLink::new(link_context(5)))
  assert_eq(span.links().length(), 1)
  span.end()
  assert_eq(exporter.spans[0].links.length(), 1)
}

///|
test "add_link ignores invalid links and non-recording spans" {
  let (tracer, exporter) = link_test_tracer(@sdk.Sampler::always_off())
  let span = tracer.start_span("op")
  span.add_link(@sdk.SpanLink::new(link_context(6)))
  span.add_link(@sdk.SpanLink::new(@api.invalid_span_context()))
  assert_eq(span.links().length(), 0)
  span.end()
  assert_eq(exporter.spans.length(), 0)
}

///|
test "add_link is ignored after the span ends" {
  let (tracer, exporter) = link_test_tracer(@sdk.Sampler::always_on())
  let span = tracer.start_span("op")
  span.end(end_time_unix_nano=100L)
  span.add_link(@sdk.SpanLink::new(link_context(7)))
  assert_eq(span.links().length(), 0)
  assert_eq(exporter.spans[0].links.length(), 0)
}

///|
test "spans without links report an empty link list" {
  let (tracer, exporter) = link_test_tracer(@sdk.Sampler::always_on())
  let span = tracer.start_span("op")
  span.end()
  assert_eq(span.links().length(), 0)
  assert_eq(exporter.spans[0].links.length(), 0)
}
