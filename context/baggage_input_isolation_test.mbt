// Baggage properties handed to a Context are copied, so the immutability of
// the context does not depend on the caller leaving its arrays untouched.

///|
test "with_baggage_entry_copies_the_input_properties" {
  let properties : Array[(String, String)] = [("priority", "high")]
  let context = @context.Context::root().with_baggage_entry(
    "tenant",
    "acme",
    properties~,
  )
  properties[0] = ("priority", "changed")
  properties.push(("extra", "value"))
  let stored = context.baggage_entry("tenant").unwrap()
  assert_eq(stored.properties, [("priority", "high")])
}

///|
test "with_baggage_entries_copies_each_input_property_array" {
  let first : Array[(String, String)] = [("priority", "high")]
  let entries : Array[@context.BaggageEntry] = [
    @context.BaggageEntry::new("tenant", "acme", properties=first),
    @context.BaggageEntry::new("user", "alice"),
  ]
  let context = @context.Context::root().with_baggage_entries(entries)
  first[0] = ("priority", "changed")
  first.push(("extra", "value"))
  entries[1] = @context.BaggageEntry::new("user", "changed")
  assert_eq(context.value("user"), Some("alice"))
  let stored = context.baggage_entry("tenant").unwrap()
  assert_eq(stored.properties, [("priority", "high")])
}

///|
test "with_baggage_from_copies_merged_properties" {
  let properties : Array[(String, String)] = [("priority", "high")]
  let source = @context.Context::root().with_baggage_entry(
    "tenant",
    "acme",
    properties~,
  )
  let merged = @context.Context::root().with_baggage_from(source)
  properties[0] = ("priority", "changed")
  assert_eq(
    merged.baggage_entry("tenant").unwrap().properties,
    [("priority", "high")],
  )
}
