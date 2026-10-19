// Tests that `TextMapCarrier::to_map` returns a copy of the carrier's own
// entries, so mutating the result does not change the carrier.

///|
test "text_map_carrier_to_map_returns_a_copy" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("a", "1")
  let exported = carrier.to_map()
  exported.set("a", "changed")
  exported.set("b", "2")
  assert_eq(carrier.length(), 1)
  assert_eq(carrier.get("a"), Some("1"))
  assert_eq(carrier.get("b"), None)
}
