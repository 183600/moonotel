// Blackbox smoke tests for the facade package.

///|
struct CapturingTransport {
  urls : Array[String]
  bodies : Array[Bytes]
  headers : Array[Map[String, String]]
  status : Int32
}

///|
fn capturing_transport() -> CapturingTransport {
  { urls: [], bodies: [], headers: [], status: 200, }
}

///|
fn CapturingTransport::send(self : CapturingTransport) -> @otlp.Transport {
  fn(url, headers, body) {
    self.urls.push(url)
    self.bodies.push(body)
    self.headers.push(headers)
    { status_code: self.status, body: b"", }
  }
}

///|
test "setup_end_to_end_with_transport" {
  @moonotel.shutdown_global_tracer_provider()
  let capture = capturing_transport()
  let provider = @moonotel.setup(
    service_name="facade-test",
    endpoint="http://collector:4318",
    transport=capture.send(),
    use_batch=false,
  )
  let tracer = @moonotel.global_tracer("facade-scope")
  let span = tracer.start_root_span("facade-op")
  span.set_attribute("custom.key", @sdk.StringValue("value"))
  span.end()
  assert_eq(capture.urls.length(), 1)
  assert_eq(capture.urls[0], "http://collector:4318/v1/traces")
  assert_true(capture.bodies[0].length() > 0)
  assert_eq(@moonotel.decode_export_response(b""), @sdk.ExportSuccess)
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "facade_without_transport_creates_provider" {
  @moonotel.shutdown_global_tracer_provider()
  let provider = @moonotel.setup(service_name="no-export")
  let tracer = @moonotel.global_tracer("scope")
  let span = tracer.start_root_span("op")
  assert_true(span.context().is_valid())
  span.end()
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "facade_propagation_round_trip" {
  let sc = @moonotel.span_context(
    @moonotel.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @moonotel.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    1,
  )
  let carrier = @moonotel.TextMapCarrier::new()
  @moonotel.inject(sc, carrier)
  let extracted = @moonotel.extract(carrier)
  assert_true(extracted is Some(_))
  assert_eq(extracted.unwrap().trace_id_hex(), sc.trace_id_hex())
  let reparsed = @moonotel.parse_traceparent(@moonotel.format_traceparent(sc))
  assert_true(reparsed is Some(_))
  assert_eq(reparsed.unwrap().span_id_hex(), sc.span_id_hex())
  assert_eq(reparsed.unwrap().trace_flags(), sc.trace_flags())
}

///|
test "tracer_start_span_with_context_parents_into_trace" {
  @moonotel.shutdown_global_tracer_provider()
  let provider = @moonotel.setup(service_name="ctx-test")
  let tracer = @moonotel.global_tracer("ctx-scope")
  let parent = tracer.start_root_span("parent-op")
  let parent_context = @moonotel.Context::root().with_span(parent.context())
  @moonotel.with_context(parent_context, () => {
    let child = tracer.start_span_with_context("child-op")
    assert_eq(child.context().trace_id_hex(), parent.context().trace_id_hex())
    assert_eq(child.parent_span_id(), parent.context().span_id())
    child.end()
  })
  parent.end()
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "tracer_explicit_context_overrides_current" {
  @moonotel.shutdown_global_tracer_provider()
  let provider = @moonotel.setup(service_name="ctx-explicit-test")
  let tracer = @moonotel.global_tracer("ctx-scope")
  let outer = tracer.start_root_span("outer-op")
  let explicit_parent = tracer.start_root_span("explicit-op")
  @moonotel.with_context(@moonotel.Context::root().with_span(outer.context()), () => {
    let child = tracer.start_span_with_context(
      "child-op",
      context=@moonotel.Context::root().with_span(explicit_parent.context()),
    )
    assert_eq(
      child.context().trace_id_hex(),
      explicit_parent.context().trace_id_hex(),
    )
    assert_eq(child.parent_span_id(), explicit_parent.context().span_id())
    child.end()
  })
  outer.end()
  explicit_parent.end()
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "facade_encode_trace_request_smoke" {
  let encoded = @moonotel.encode_trace_request([])
  assert_eq(encoded.length(), 0)
}

///|
test "setup_merges_resource_attributes" {
  @moonotel.shutdown_global_tracer_provider()
  let attributes : Map[String, @moonotel.AttributeValue] = Map([])
  attributes.set("deployment.environment", @sdk.StringValue("test"))
  let provider = @moonotel.setup(
    service_name="resource-test",
    resource_attributes=attributes,
  )
  let resource = provider.resource()
  assert_eq(
    resource.get("deployment.environment"),
    Some(@sdk.StringValue("test")),
  )
  assert_eq(
    resource.get(@moonotel.TELEMETRY_SDK_NAME),
    Some(@sdk.StringValue("opentelemetry")),
  )
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "setup_applies_span_limits" {
  @moonotel.shutdown_global_tracer_provider()
  let provider = @moonotel.setup(
    service_name="limits-facade",
    span_limits=@moonotel.SpanLimits::new(attribute_count_limit=1),
  )
  let tracer = @moonotel.global_tracer("limits-scope")
  let span = tracer.start_root_span("op")
  span.set_attribute("a", @sdk.StringValue("1"))
  span.set_attribute("b", @sdk.StringValue("2"))
  assert_eq(span.attributes().length(), 1)
  assert_eq(span.dropped_attributes_count(), 1)
  span.end()
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "facade_baggage_round_trip" {
  let context = @moonotel.Context::root().with_value("user.id", "42")
  let carrier = @moonotel.TextMapCarrier::new()
  @moonotel.inject_baggage(context, carrier)
  assert_eq(carrier.get(@moonotel.baggage_header_name()), Some("user.id=42"))
  let restored = @moonotel.extract_baggage_context(carrier)
  assert_eq(restored.value("user.id"), Some("42"))
}

///|
test "facade_baggage_entries_round_trip" {
  let entries : Array[@moonotel.BaggageEntry] = [
    @moonotel.BaggageEntry::new("user.id", "42", properties=[("ttl", "1")]),
  ]
  let carrier = @moonotel.TextMapCarrier::new()
  @moonotel.inject_baggage_entries(entries, carrier)
  assert_eq(
    carrier.get(@moonotel.baggage_header_name()),
    Some("user.id=42;ttl=1"),
  )
  let restored = @moonotel.extract_baggage_entries(carrier)
  assert_eq(restored.length(), 1)
  assert_eq(restored[0].key, "user.id")
  assert_eq(restored[0].properties, [("ttl", "1")])
  assert_eq(
    @moonotel.format_baggage_entries(restored),
    "user.id=42;ttl=1",
  )
  assert_eq(@moonotel.parse_baggage_entries("a=1;p=2")[0].properties, [
    ("p", "2"),
  ])
}
