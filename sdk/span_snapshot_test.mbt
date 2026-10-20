// Tests that the `SpanData` snapshot handed to exporters is independent of the
// span and of the caller-owned containers it was built from.

///|
test "span_data_snapshot_does_not_alias_span_or_caller_state" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="snapshot")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("snapshot")
  let parent_ctx = @api.span_context(
    @api.bytes_from_hex("0102030405060708090a0b0c0d0e0f10").unwrap(),
    @api.bytes_from_hex("1112131415161718").unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let values : Array[String] = ["a"]
  let event_values : Array[String] = ["e"]
  let link_values : Array[String] = ["l"]
  let span = tracer.start_span(
    "op",
    parent=parent_ctx,
    links=[
      @sdk.SpanLink::new(
        parent_ctx,
        attributes=Map([("k", @sdk.StringArrayValue(link_values))]),
      ),
    ],
  )
  span.set_string_array_attribute("arr", values)
  span.add_event(
    "ev",
    attributes=Map([("k", @sdk.StringArrayValue(event_values))]),
  )
  span.end()
  let data = exporter.exported_spans()[0]
  // Mutating the caller's arrays must not change the snapshot.
  values.push("b")
  event_values.push("b")
  link_values.push("b")
  parent_ctx.span_id_view()[0] = 99
  assert_eq(data.attributes.get("arr"), Some(@sdk.StringArrayValue(["a"])))
  assert_eq(
    data.events[0].attributes.get("k"),
    Some(@sdk.StringArrayValue(["e"])),
  )
  assert_eq(
    data.links[0].attributes.get("k"),
    Some(@sdk.StringArrayValue(["l"])),
  )
  assert_eq(@api.bytes_to_hex(data.parent_span_id), "1112131415161718")
  // Mutating the snapshot must not change the provider resource.
  data.resource.set("injected", @sdk.StringValue("x"))
  let span2 = tracer.start_span("op2")
  span2.end()
  let data2 = exporter.exported_spans()[1]
  assert_true(data2.resource.get("injected") is None)
}

///|
test "span_does_not_alias_caller_values_before_end" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="immutable")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("immutable")
  let values : Array[String] = ["a"]
  let event_values : Array[String] = ["e"]
  let link_values : Array[String] = ["l"]
  let span = tracer.start_span("op")
  span.set_string_array_attribute("arr", values)
  span.add_event(
    "ev",
    attributes=Map([("k", @sdk.StringArrayValue(event_values))]),
  )
  span.add_link(
    @sdk.SpanLink::new(
      @api.span_context(
        @api.bytes_from_hex("0102030405060708090a0b0c0d0e0f10").unwrap(),
        @api.bytes_from_hex("1112131415161718").unwrap(),
        @api.TRACE_FLAGS_SAMPLED,
      ),
      attributes=Map([("k", @sdk.StringArrayValue(link_values))]),
    ),
  )
  values.push("b")
  event_values.push("b")
  link_values.push("b")
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.get("arr"), Some(@sdk.StringArrayValue(["a"])))
  assert_eq(
    data.events[0].attributes.get("k"),
    Some(@sdk.StringArrayValue(["e"])),
  )
  assert_eq(
    data.links[0].attributes.get("k"),
    Some(@sdk.StringArrayValue(["l"])),
  )
}
