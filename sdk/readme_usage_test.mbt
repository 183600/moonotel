// Verifies that the "Getting started" usage from the README compiles and
// records the documented data.

///|
test "readme_getting_started_usage_records_span" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="checkout")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("checkout", version="1.0.0")
  let span = tracer.start_root_span("charge-card", kind=@api.SpanKind::Client)
  span.set_attribute("payment.provider", @sdk.StringValue("acme"))
  span.add_event("retry", attributes={ "attempt": @sdk.IntValue(1) })
  span.set_status(@api.StatusCode::Ok)
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.name, "charge-card")
  assert_eq(data.kind, @api.SpanKind::Client)
  assert_eq(data.attributes.get("payment.provider"), Some(@sdk.StringValue("acme")))
  assert_eq(data.events.length(), 1)
  assert_eq(data.events[0].attributes.get("attempt"), Some(@sdk.IntValue(1L)))
  assert_eq(data.status, @api.StatusCode::Ok)
}
