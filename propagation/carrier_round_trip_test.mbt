// `from_map` and `to_map` share the backing map; case-insensitive lookups can
// still miss.

///|
test "text_map_carrier_from_map_shares_the_backing_map" {
  let entries : Map[String, String] = Map([])
  entries.set("traceparent", "value")
  let carrier = @propagation.TextMapCarrier::from_map(entries)
  entries.set("extra", "later")
  assert_eq(carrier.length(), 2)
  assert_eq(carrier.get("extra"), Some("later"))
  assert_eq(carrier.to_map().get("traceparent"), Some("value"))
}

///|
test "text_map_carrier_case_insensitive_lookup_misses" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("abc", "1")
  assert_eq(carrier.get("abd"), None)
  assert_eq(carrier.get("ab"), None)
}
