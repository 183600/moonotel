// Lookups through `with_baggage_entries` must fall back to outer contexts for
// keys that the list does not carry, and the flattened views must include the
// list's members.

///|
test "baggage_list_lookup_falls_back_to_outer_values" {
  let context = @context.Context::root()
    .with_value("outer", "1")
    .with_baggage_entries([
      @context.BaggageEntry::new("inner", "2", properties=[("p", "v")]),
    ])
  assert_eq(context.value("outer"), Some("1"))
  assert_eq(context.baggage_entry("outer").unwrap().value, "1")
  assert_eq(context.value("inner"), Some("2"))
  let inner = context.baggage_entry("inner").unwrap()
  assert_eq(inner.properties, [("p", "v")])
}

///|
test "baggage_list_members_are_visible_in_flattened_views" {
  let context = @context.Context::root()
    .with_value("outer", "1")
    .with_baggage_entries([
      @context.BaggageEntry::new("inner", "2"),
      @context.BaggageEntry::new("also", "3"),
    ])
  let entries = context.baggage_entries()
  assert_eq(entries.length(), 3)
  let values = context.baggage()
  assert_eq(values.length(), 3)
  assert_eq(values.get("inner"), Some("2"))
  assert_eq(values.get("also"), Some("3"))
  assert_eq(values.get("outer"), Some("1"))
  assert_true(context.has_baggage())
}

///|
test "removing_a_key_from_a_baggage_list_hides_outer_values" {
  let context = @context.Context::root()
    .with_value("outer", "1")
    .with_baggage_entries([
      @context.BaggageEntry::new("inner", "2"),
    ])
    .without_value("outer")
  assert_eq(context.value("outer"), None)
  assert_eq(context.baggage_entry("outer"), None)
  let entries = context.baggage_entries()
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].key, "inner")
  assert_eq(context.baggage().get("outer"), None)
  assert_eq(context.baggage().get("inner"), Some("2"))
}
