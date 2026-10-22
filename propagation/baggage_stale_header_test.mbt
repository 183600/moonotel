// Baggage injection must leave the carrier describing exactly the baggage of
// the injected context. A reused carrier may still hold a header from an
// earlier injection; that stale header must not be propagated.

///|
test "inject_baggage_removes_a_stale_header" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(@propagation.baggage_header_name(), "stale=value")
  @propagation.inject_baggage(@context.Context::root(), carrier)
  assert_eq(carrier.get(@propagation.baggage_header_name()), None)
  assert_eq(carrier.length(), 0)
}

///|
test "inject_baggage_removes_a_stale_header_when_every_value_was_removed" {
  let context = @context.Context::root()
    .with_value("user.id", "42")
    .without_value("user.id")
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(@propagation.baggage_header_name(), "user.id=stale")
  @propagation.inject_baggage(context, carrier)
  assert_eq(carrier.get(@propagation.baggage_header_name()), None)
}

///|
test "inject_baggage_replaces_a_stale_header_with_the_context_baggage" {
  let context = @context.Context::root().with_value("user.id", "42")
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(@propagation.baggage_header_name(), "other=stale")
  @propagation.inject_baggage(context, carrier)
  assert_eq(carrier.get(@propagation.baggage_header_name()), Some("user.id=42"))
}

///|
test "inject_baggage_entries_removes_a_stale_header" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(@propagation.baggage_header_name(), "stale=value")
  @propagation.inject_baggage_entries([], carrier)
  assert_eq(carrier.get(@propagation.baggage_header_name()), None)
  assert_eq(carrier.length(), 0)
}

///|
test "inject_baggage_entries_removes_a_stale_header_for_only_invalid_names" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(@propagation.baggage_header_name(), "stale=value")
  @propagation.inject_baggage_entries([
    @propagation.BaggageEntry::new("", "ignored"),
  ], carrier)
  assert_eq(carrier.get(@propagation.baggage_header_name()), None)
}

///|
test "baggage_propagator_removes_a_stale_header" {
  let propagator = @propagation.BaggagePropagator::new()
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(@propagation.baggage_header_name(), "stale=value")
  propagator.inject(@context.Context::root(), carrier)
  assert_eq(carrier.get(@propagation.baggage_header_name()), None)
  assert_eq(carrier.length(), 0)
}

///|
test "inject_baggage_clears_an_external_stale_header" {
  let store : Map[String, String] = Map([
    (@propagation.baggage_header_name(), "stale=value"),
  ])
  let carrier = @propagation.TextMapCarrier::from_getter_setter(
    fn(key) { store.get(key) },
    fn(key, value) { store.set(key, value) },
    remove=fn(key) { store.remove(key) },
  )
  @propagation.inject_baggage(@context.Context::root(), carrier)
  assert_eq(store.get(@propagation.baggage_header_name()), None)
}
