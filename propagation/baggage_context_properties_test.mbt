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
      // The key-only `;flag` property is valid (W3C `property =/ key OWS`).
      assert_eq(entry.properties, [("priority", "high"), ("flag", "")])
    }
    None => fail("expected userId baggage")
  }
  match context.baggage_entry("tenant") {
    Some(entry) => assert_eq(entry.properties.length(), 0)
    None => fail("expected tenant baggage")
  }
}

///|
test "extract_baggage_trims_property_whitespace" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    @propagation.baggage_header_name(),
    "userId=alice ; priority = high ; flag ,tenant=acme",
  )
  let context = @propagation.extract_baggage_context(carrier)
  match context.baggage_entry("userId") {
    Some(entry) => {
      assert_eq(entry.value, "alice")
      assert_eq(entry.properties, [("priority", "high"), ("flag", "")])
    }
    None => fail("expected userId baggage")
  }
  match context.baggage_entry("tenant") {
    Some(entry) => assert_eq(entry.value, "acme")
    None => fail("expected tenant baggage")
  }
}

///|
test "inject_baggage_preserves_properties" {
  let context = @context.Context::root().with_baggage_entry("userId", "alice", properties=[
    ("priority", "a b"),
    ("source", "checkout"),
  ])
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
test "context_baggage_header_sorts_small_entry_lists" {
  let context = @context.Context::root()
    .with_baggage_entry("zebra", "1", properties=[("p", "z")])
    .with_baggage_entry("alpha", "2")
    .with_baggage_entry("middle", "3")
  assert_eq(
    @propagation.context_baggage_header(context),
    Some("alpha=2,middle=3,zebra=1;p=z"),
  )
}

///|
test "context_baggage_header_sorts_large_entry_lists" {
  let keys : Array[String] = [
    "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q",
    "aa",
  ]
  let mut context = @context.Context::root()
  for key in keys {
    context = context.with_value(key, "1")
  }
  assert_eq(
    @propagation.context_baggage_header(context),
    Some("aa=1,b=1,c=1,d=1,e=1,f=1,g=1,h=1,i=1,j=1,k=1,l=1,m=1,n=1,o=1,p=1,q=1"),
  )
}

///|
test "extract_context_preserves_baggage_properties_with_traceparent" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    @propagation.traceparent_header_name(),
    "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01",
  )
  carrier.set(@propagation.baggage_header_name(), "tenant=acme;priority=high")
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
  let tracecontext : &@propagation.TextMapPropagator = @propagation.TraceContextPropagator::new()
  let baggage : &@propagation.TextMapPropagator = @propagation.BaggagePropagator::new()
  let propagator = @propagation.CompositePropagator::new([tracecontext, baggage])
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(@propagation.baggage_header_name(), "tenant=acme;priority=high")
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
