// Boundary coverage for collection limits and the console formatter: empty
// attribute keys are ignored rather than counted as drops, and every typed
// array value is rendered by the console exporter.

///|
fn limit_edge_span(
  limits : SpanLimits,
  name : String,
) -> (SpanSdk, InMemorySpanExporter) {
  let exporter = InMemorySpanExporter::new()
  let provider = TracerProviderSdk::new(service_name="limit-edge")
    .with_span_processor(SimpleSpanProcessor::new(exporter))
    .with_sampler(Sampler::always_on())
    .with_span_limits(limits)
  (provider.get_tracer("limit-edge").start_root_span(name), exporter)
}

///|
test "event_attribute_with_an_empty_key_is_ignored_without_a_drop" {
  let (span, exporter) = limit_edge_span(
    SpanLimits::new(event_attribute_count_limit=1),
    "event-empty-key",
  )
  span.add_event(
    "event",
    attributes=Map([
      ("", StringValue("invalid")),
      ("kept", IntValue(7L)),
    ]),
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.events.length(), 1)
  assert_eq(data.events[0].attributes.length(), 1)
  assert_eq(data.events[0].attributes.get("kept"), Some(IntValue(7L)))
  assert_eq(data.events[0].dropped_attributes_count, 0)
}

///|
test "link_attribute_with_an_empty_key_is_ignored_without_a_drop" {
  let (span, exporter) = limit_edge_span(
    SpanLimits::new(link_attribute_count_limit=1),
    "link-empty-key",
  )
  let linked = @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
  )
  span.add_link(
    SpanLink::new(
      linked,
      attributes=Map([
        ("", StringValue("invalid")),
        ("kept", IntValue(9L)),
      ]),
    ),
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.links.length(), 1)
  assert_eq(data.links[0].attributes.length(), 1)
  assert_eq(data.links[0].attributes.get("kept"), Some(IntValue(9L)))
  assert_eq(data.links[0].dropped_attributes_count, 0)
}

///|
test "set_attributes_ignores_empty_keys_without_consuming_the_count_limit" {
  let (span, exporter) = limit_edge_span(
    SpanLimits::new(attribute_count_limit=1),
    "span-empty-key",
  )
  span.set_attributes(Map([
    ("", StringValue("invalid")),
    ("kept", IntValue(1L)),
  ]))
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.length(), 1)
  assert_eq(data.attributes.get("kept"), Some(IntValue(1L)))
  assert_eq(data.dropped_attributes_count, 0)
}

///|
test "console_format_renders_int_and_double_array_values" {
  let data : SpanData = {
    name: "arrays",
    span_context: @api.span_context(
      @api.bytes_from_hex("11111111111111111111111111111111").unwrap(),
      @api.bytes_from_hex("2222222222222222").unwrap(),
      1,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 0L,
    end_time_unix_nano: 0L,
    attributes: Map([
      ("ints", IntArrayValue([1L, -2L, 3L])),
      ("doubles", DoubleArrayValue([0.5, -1.0])),
    ]),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: ResourceAttributes::new(Map([])),
    scope_name: "probe",
    scope_version: "",
  }
  let rendered = format_span(data)
  assert_true(rendered.contains("ints=[1, -2, 3]"))
  assert_true(rendered.contains("doubles=[0.5, -1]"))
}
