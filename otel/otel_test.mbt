// Blackbox smoke tests for the facade package.

///|
struct CapturingTransport {
  urls : Array[String]
  bodies : Array[Bytes]
  status : Int32
}

///|
fn capturing_transport() -> CapturingTransport {
  { urls: [], bodies: [], status: 200, }
}

///|
fn CapturingTransport::send(self : CapturingTransport) -> @otlp.Transport {
  fn(url, _headers, body) {
    self.urls.push(url)
    self.bodies.push(body)
    { status_code: self.status, body: b"", }
  }
}

///|
test "setup_end_to_end_with_transport" {
  @otel.shutdown_global_tracer_provider()
  let capture = capturing_transport()
  let provider = @otel.setup(
    service_name="facade-test",
    endpoint="http://collector:4318",
    transport=capture.send(),
    use_batch=false,
  )
  let tracer = @otel.global_tracer("facade-scope")
  let span = tracer.start_root_span("facade-op")
  span.set_attribute("custom.key", @sdk.StringValue("value"))
  span.end()
  assert_eq(capture.urls.length(), 1)
  assert_eq(capture.urls[0], "http://collector:4318/v1/traces")
  assert_true(capture.bodies[0].length() > 0)
  assert_eq(@otel.decode_export_response(b""), @sdk.ExportSuccess)
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}

///|
test "facade_without_transport_creates_provider" {
  @otel.shutdown_global_tracer_provider()
  let provider = @otel.setup(service_name="no-export")
  let tracer = @otel.global_tracer("scope")
  let span = tracer.start_root_span("op")
  assert_true(span.context().is_valid())
  span.end()
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}

///|
test "facade_propagation_round_trip" {
  let sc = @otel.span_context(
    @otel.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @otel.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    1,
  )
  let carrier = @otel.TextMapCarrier::new()
  @otel.inject(sc, carrier)
  let extracted = @otel.extract(carrier)
  assert_true(extracted is Some(_))
  assert_eq(extracted.unwrap().trace_id_hex(), sc.trace_id_hex())
  let reparsed = @otel.parse_traceparent(@otel.format_traceparent(sc))
  assert_true(reparsed is Some(_))
  assert_eq(reparsed.unwrap().span_id_hex(), sc.span_id_hex())
  assert_eq(reparsed.unwrap().trace_flags(), sc.trace_flags())
}

///|
test "tracer_start_span_with_context_parents_into_trace" {
  @otel.shutdown_global_tracer_provider()
  let provider = @otel.setup(service_name="ctx-test")
  let tracer = @otel.global_tracer("ctx-scope")
  let parent = tracer.start_root_span("parent-op")
  let parent_context = @otel.Context::root().with_span(parent.context())
  @otel.with_context(parent_context, () => {
    let child = tracer.start_span_with_context("child-op")
    assert_eq(child.context().trace_id_hex(), parent.context().trace_id_hex())
    assert_eq(child.parent_span_id(), parent.context().span_id())
    child.end()
  })
  parent.end()
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}

///|
test "tracer_explicit_context_overrides_current" {
  @otel.shutdown_global_tracer_provider()
  let provider = @otel.setup(service_name="ctx-explicit-test")
  let tracer = @otel.global_tracer("ctx-scope")
  let outer = tracer.start_root_span("outer-op")
  let explicit_parent = tracer.start_root_span("explicit-op")
  @otel.with_context(@otel.Context::root().with_span(outer.context()), () => {
    let child = tracer.start_span_with_context(
      "child-op",
      context=@otel.Context::root().with_span(explicit_parent.context()),
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
  @otel.shutdown_global_tracer_provider()
}

///|
test "facade_encode_trace_request_smoke" {
  let encoded = @otel.encode_trace_request([])
  assert_eq(encoded.length(), 0)
}

///|
test "setup_merges_resource_attributes" {
  @otel.shutdown_global_tracer_provider()
  let attributes : Map[String, @otel.AttributeValue] = Map([])
  attributes.set("deployment.environment", @sdk.StringValue("test"))
  let provider = @otel.setup(
    service_name="resource-test",
    resource_attributes=attributes,
  )
  let resource = provider.resource()
  assert_eq(
    resource.get("deployment.environment"),
    Some(@sdk.StringValue("test")),
  )
  assert_eq(
    resource.get(@otel.TELEMETRY_SDK_NAME),
    Some(@sdk.StringValue("opentelemetry")),
  )
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}

///|
test "setup_applies_span_limits" {
  @otel.shutdown_global_tracer_provider()
  let provider = @otel.setup(
    service_name="limits-facade",
    span_limits=@otel.SpanLimits::new(attribute_count_limit=1),
  )
  let tracer = @otel.global_tracer("limits-scope")
  let span = tracer.start_root_span("op")
  span.set_attribute("a", @sdk.StringValue("1"))
  span.set_attribute("b", @sdk.StringValue("2"))
  assert_eq(span.attributes().length(), 1)
  assert_eq(span.dropped_attributes_count(), 1)
  span.end()
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}

///|
test "facade_baggage_round_trip" {
  let context = @otel.Context::root().with_value("user.id", "42")
  let carrier = @otel.TextMapCarrier::new()
  @otel.inject_baggage(context, carrier)
  assert_eq(carrier.get(@otel.baggage_header_name()), Some("user.id=42"))
  let restored = @otel.extract_baggage_context(carrier)
  assert_eq(restored.value("user.id"), Some("42"))
}
