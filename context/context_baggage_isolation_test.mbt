// Tests that baggage accessors do not expose the Context's mutable property
// arrays.

///|
test "baggage_entry_does_not_expose_stored_properties" {
  let context = @context.Context::root().with_baggage_entry(
    "tenant",
    "acme",
    properties=[("priority", "high")],
  )
  let entry = context.baggage_entry("tenant").unwrap()
  entry.properties[0] = ("priority", "changed")
  entry.properties.push(("extra", "value"))
  let stored = context.baggage_entry("tenant").unwrap()
  assert_eq(stored.properties, [("priority", "high")])
}

///|
test "baggage_entries_does_not_expose_stored_properties" {
  let context = @context.Context::root().with_baggage_entry(
    "tenant",
    "acme",
    properties=[("priority", "high")],
  )
  let entries = context.baggage_entries()
  entries[0].properties[0] = ("priority", "changed")
  entries[0].properties.push(("extra", "value"))
  let stored = context.baggage_entries()[0]
  assert_eq(stored.properties, [("priority", "high")])
}
