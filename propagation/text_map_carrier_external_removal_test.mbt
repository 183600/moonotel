// A write-through carrier can also delete from its external header store.
// This is what lets `inject` clear a stale `tracestate` header when the new
// context carries no state.

///|
test "remove forwards to the external store when a callback is supplied" {
  let store : Map[String, String] = Map([("x-token", "old")])
  let carrier = @propagation.TextMapCarrier::from_getter_setter(
    fn(key) { store.get(key) },
    fn(key, value) { store.set(key, value) },
    remove=fn(key) { store.remove(key.to_lower()) },
  )
  carrier.remove("X-Token")
  assert_eq(store.get("x-token"), None)
}

///|
test "inject clears a stale external tracestate" {
  let store : Map[String, String] = Map([
    ("traceparent", "00-00000000000000000000000000000000-0000000000000000-00"),
    ("tracestate", "stale=value"),
  ])
  let carrier = @propagation.TextMapCarrier::from_getter_setter(
    fn(key) { store.get(key) },
    fn(key, value) { store.set(key, value) },
    remove=fn(key) { store.remove(key) },
  )
  let context = @api.span_context(
    [
      0x4b, 0xf9, 0x2f, 0x35, 0x9d, 0x1e, 0x75, 0xb7, 0x61, 0x8a, 0x2d, 0x1f,
      0x3c, 0x4e, 0x5a, 0x6b,
    ],
    [0x00, 0xf0, 0x67, 0xaa, 0x0b, 0xa9, 0x02, 0xb7],
    @api.TRACE_FLAGS_SAMPLED,
  )
  @propagation.inject(context, carrier)
  assert_eq(
    store.get("traceparent"),
    Some(@propagation.format_traceparent(context)),
  )
  assert_eq(store.get("tracestate"), None)
}

///|
test "a carrier without a remove callback keeps local removal only" {
  let store : Map[String, String] = Map([("x-token", "old")])
  let carrier = @propagation.TextMapCarrier::from_getter_setter(
    fn(key) { store.get(key) },
    fn(key, value) { store.set(key, value) },
  )
  carrier.remove("x-token")
  assert_eq(store.get("x-token"), Some("old"))
}
