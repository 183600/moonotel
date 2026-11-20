///|
test "sampler cannot mutate span sampling inputs" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let expected_trace = @api.bytes_to_hex(
    @sdk.IdGenerator::deterministic(42).generate_trace_id(),
  )
  let link_context = @api.span_context(
    Array::make(16, 3),
    Array::make(8, 4),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let expected_link_trace = link_context.trace_id_hex()
  let sampler = @sdk.Sampler::new("MutatingSampler", fn(parameters) {
    parameters.trace_id[0] = 0xEE
    parameters.attributes.remove("kept")
    parameters.links[0] = @sdk.SpanLink::new(@api.invalid_span_context())
    @sdk.sampling_decision_record_and_sample()
  })
  let provider = @sdk.TracerProviderSdk::new(service_name="sampler-isolation")
    .with_id_generator(@sdk.IdGenerator::deterministic(42))
    .with_sampler(sampler)
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("kept", @sdk.StringValue("value"))
  let span = provider
    .get_tracer("sampler-isolation")
    .start_span("op", attributes~, links=[@sdk.SpanLink::new(link_context)])
  assert_eq(span.context().trace_id_hex(), expected_trace)
  assert_eq(span.attributes().get("kept"), Some(@sdk.StringValue("value")))
  assert_eq(span.links()[0].span_context.trace_id_hex(), expected_link_trace)
  span.end()
  assert_eq(
    exporter.exported_spans()[0].span_context.trace_id_hex(),
    expected_trace,
  )
}

///|
test "sampler cannot mutate array attribute payloads or link attributes" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let link_context = @api.span_context(
    Array::make(16, 5),
    Array::make(8, 6),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let sampler = @sdk.Sampler::new("PayloadMutatingSampler", fn(parameters) {
    match parameters.attributes.get("items") {
      Some(@sdk.StringArrayValue(items)) => items[0] = "mutated"
      _ => ()
    }
    parameters.links[0].attributes.set(
      "injected",
      @sdk.StringValue("by-sampler"),
    )
    @sdk.sampling_decision_record_and_sample()
  })
  let provider = @sdk.TracerProviderSdk::new(service_name="sampler-isolation")
    .with_sampler(sampler)
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("items", @sdk.StringArrayValue(["original"]))
  let link_attributes : Map[String, @sdk.AttributeValue] = Map([])
  link_attributes.set("original", @sdk.StringValue("link"))
  let span = provider
    .get_tracer("sampler-isolation")
    .start_span("op", attributes~, links=[
      @sdk.SpanLink::new(link_context, attributes=link_attributes),
    ])
  assert_eq(
    span.attributes().get("items"),
    Some(@sdk.StringArrayValue(["original"])),
  )
  assert_eq(span.links()[0].attributes.get("injected"), None)
  assert_eq(
    span.links()[0].attributes.get("original"),
    Some(@sdk.StringValue("link")),
  )
  span.end()
  let exported = exporter.exported_spans()[0]
  assert_eq(
    exported.attributes.get("items"),
    Some(@sdk.StringArrayValue(["original"])),
  )
  assert_eq(exported.links[0].attributes.get("injected"), None)
}
