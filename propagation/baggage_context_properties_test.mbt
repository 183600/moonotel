// Tests for preserving W3C baggage properties across Context extraction and
// injection.

///|
test "extract_baggage_context_preserves_properties" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    @propagation.baggage_header_name(),
    "userId=alice;priority=high;flag,tenant=acme",
  )
  let context = @propagation.extract_baggage_context(carrier)
  match context.baggage_entry("userId") {
    Some(entry) => {
      assert_eq(entry.value, "alice")
      assert_eq(entry.properties, [("priority", "high")])
    }
    None => fail("expected userId baggage")
  }
  match context.baggage_entry("tenant") {
    Some(entry) => assert_eq(entry.properties.length(), 0)
    None => fail("expected tenant baggage")
  }
}

///|
test "inject_baggage_preserves_properties" {
  let context = @context.Context::root().with_baggage_entry(
    "userId",
    "alice",
    properties=[("priority", "a b"), ("source", "checkout")],
  )
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_baggage(context, carrier)
  assert_eq(
    carrier.get(@propagation.baggage_header_name()),
    Some("userId=alice;priority=a%20b;source=checkout"),
  )
}

///|
test "context_baggage_header_keeps_properties_after_extraction" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    @propagation.baggage_header_name(),
    "tenant=acme;priority=high,userId=alice",
  )
  let context = @propagation.extract_baggage_context(carrier)
  let restored = @propagation.TextMapCarrier::new()
  @propagation.inject_baggage(context, restored)
  assert_eq(
    restored.get(@propagation.baggage_header_name()),
    Some("tenant=acme;priority=high,userId=alice"),
  )
}

///|
test "extract_context_preserves_baggage_properties_with_traceparent" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    @propagation.traceparent_header_name(),
    "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01",
  )
  carrier.set(
    @propagation.baggage_header_name(),
    "tenant=acme;priority=high",
  )
  let context = @propagation.extract_context(carrier)
  assert_true(context.span_context() is Some(_))
  match context.baggage_entry("tenant") {
    Some(entry) => {
      assert_eq(entry.value, "acme")
      assert_eq(entry.properties, [("priority", "high")])
    }
    None => fail("expected tenant baggage")
  }
}

///|
test "composite_propagator_preserves_baggage_properties" {
  let tracecontext : &@propagation.TextMapPropagator =
    @propagation.TraceContextPropagator::new()
  let baggage : &@propagation.TextMapPropagator =
    @propagation.BaggagePropagator::new()
  let propagator = @propagation.CompositePropagator::new([
    tracecontext,
    baggage,
  ])
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    @propagation.baggage_header_name(),
    "tenant=acme;priority=high",
  )
  let context = propagator.extract(carrier)
  match context.baggage_entry("tenant") {
    Some(entry) => assert_eq(entry.properties, [("priority", "high")])
    None => fail("expected tenant baggage")
  }
}

///|
test "inject_baggage_omits_removed_entry_with_properties" {
  let context = @context.Context::root()
    .with_baggage_entry("k", "v", properties=[("p", "1")])
    .without_value("k")
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_baggage(context, carrier)
  assert_eq(carrier.get(@propagation.baggage_header_name()), None)
}
