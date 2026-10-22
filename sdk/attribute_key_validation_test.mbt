// The OpenTelemetry attribute data model requires non-empty keys. These tests
// cover the SDK boundary: invalid keys must never be recorded or exported, and
// they are not counted as attributes dropped because of a limit.

///|
fn valid_link_context() -> @api.SpanContext {
  @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
  )
}

///|
test "span_ignores_empty_attribute_keys" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="attribute-keys")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("attribute-keys")
  let span = tracer.start_root_span("op")
  span.set_attribute("", @sdk.StringValue("ignored"))
  span.set_attribute("kept", @sdk.IntValue(1L))
  span.set_attributes(
    Map([
      ("", @sdk.StringValue("ignored-too")),
      ("also-kept", @sdk.BoolValue(true)),
    ]),
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.length(), 2)
  assert_eq(data.attributes.get(""), None)
  assert_eq(data.attributes.get("kept"), Some(@sdk.IntValue(1L)))
  assert_eq(data.attributes.get("also-kept"), Some(@sdk.BoolValue(true)))
  // An invalid key is not an attribute, so it must not inflate the limit
  // accounting either.
  assert_eq(data.dropped_attributes_count, 0)
}

///|
test "event_and_link_ignore_empty_attribute_keys" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="attribute-keys")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("attribute-keys")
  let span = tracer.start_root_span("op")
  span.add_event(
    "event",
    attributes=Map([
      ("", @sdk.StringValue("ignored")),
      ("event-kept", @sdk.IntValue(2L)),
    ]),
  )
  span.add_link(
    @sdk.SpanLink::new(
      valid_link_context(),
      attributes=Map([
        ("", @sdk.StringValue("ignored")),
        ("link-kept", @sdk.IntValue(3L)),
      ]),
    ),
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.events.length(), 1)
  assert_eq(data.events[0].attributes.length(), 1)
  assert_eq(data.events[0].attributes.get(""), None)
  assert_eq(
    data.events[0].attributes.get("event-kept"),
    Some(@sdk.IntValue(2L)),
  )
  assert_eq(data.events[0].dropped_attributes_count, 0)
  assert_eq(data.links.length(), 1)
  assert_eq(data.links[0].attributes.length(), 1)
  assert_eq(data.links[0].attributes.get(""), None)
  assert_eq(
    data.links[0].attributes.get("link-kept"),
    Some(@sdk.IntValue(3L)),
  )
  assert_eq(data.links[0].dropped_attributes_count, 0)
}

///|
test "resource_ignores_empty_attribute_keys" {
  let resource = @sdk.Resource::new(
    attributes=Map([
      ("", @sdk.StringValue("ignored")),
      ("service.name", @sdk.StringValue("checkout")),
    ]),
  )
  assert_eq(resource.length(), 1)
  assert_eq(resource.get(""), None)
  assert_eq(
    resource.get("service.name"),
    Some(@sdk.StringValue("checkout")),
  )
  // Updating with an invalid key leaves the resource unchanged.
  let unchanged = resource.with_attribute("", @sdk.StringValue("ignored"))
  assert_eq(unchanged.length(), 1)
  assert_eq(unchanged.get(""), None)
  // Merging an invalid attribute cannot reintroduce it.
  let merged = resource.merge(
    @sdk.Resource::new(attributes=Map([("", @sdk.StringValue("ignored"))])),
  )
  assert_eq(merged.length(), 1)
  assert_eq(merged.get(""), None)
}

///|
test "resource_snapshot_ignores_empty_attribute_keys" {
  let snapshot = @sdk.ResourceAttributes::new(
    Map([
      ("", @sdk.StringValue("ignored")),
      ("k", @sdk.StringValue("v")),
    ]),
  )
  assert_eq(snapshot.length(), 1)
  assert_eq(snapshot.get(""), None)
  assert_eq(snapshot.get("k"), Some(@sdk.StringValue("v")))
  snapshot.set("", @sdk.StringValue("ignored"))
  assert_eq(snapshot.length(), 1)
  assert_eq(snapshot.get(""), None)
}
