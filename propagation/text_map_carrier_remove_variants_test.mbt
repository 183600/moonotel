// A `TextMapCarrier` with locally stored fields can hold differently cased
// spellings of the same header (a plain `set` does not collapse them). A
// single `remove` must still clear every spelling, not just the exact key.

///|
test "remove clears_every_casing_of_a_locally_stored_field" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("X-Test", "1")
  carrier.set("x-test", "2")
  carrier.set("X-TEST", "3")
  assert_eq(carrier.get_all("x-test").length(), 3)
  assert_eq(carrier.length(), 3)
  carrier.remove("X-tEsT")
  assert_eq(carrier.length(), 0)
  assert_eq(carrier.get_all("x-test"), [])
}
