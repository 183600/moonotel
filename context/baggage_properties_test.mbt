// Tests for baggage properties stored in a Context.

///|
test "with_baggage_entry_preserves_properties" {
  let context = @context.Context::root().with_baggage_entry(
    "tenant",
    "acme",
    properties=[("priority", "high"), ("region", "eu")],
  )
  assert_eq(context.value("tenant"), Some("acme"))
  match context.baggage_entry("tenant") {
    Some(entry) => {
      assert_eq(entry.key, "tenant")
      assert_eq(entry.value, "acme")
      assert_eq(entry.properties.length(), 2)
      assert_eq(entry.properties[0], ("priority", "high"))
      assert_eq(entry.properties[1], ("region", "eu"))
    }
    None => fail("expected the baggage entry")
  }
  let entries = context.baggage_entries()
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].properties.length(), 2)
}

///|
test "baggage_entry_without_properties_has_empty_array" {
  let context = @context.Context::root().with_baggage_entry("k", "v")
  match context.baggage_entry("k") {
    Some(entry) => assert_eq(entry.properties.length(), 0)
    None => fail("expected the baggage entry")
  }
}

///|
test "with_baggage_entries_applies_members_in_order" {
  let context = @context.Context::root().with_baggage_entries([
    @context.BaggageEntry::new("k", "first", properties=[("p", "1")]),
    @context.BaggageEntry::new("k", "second", properties=[("p", "2")]),
  ])
  assert_eq(context.value("k"), Some("second"))
  match context.baggage_entry("k") {
    Some(entry) => {
      assert_eq(entry.value, "second")
      assert_eq(entry.properties, [("p", "2")])
    }
    None => fail("expected the baggage entry")
  }
}

///|
test "without_value_hides_baggage_properties" {
  let context = @context.Context::root()
    .with_baggage_entry("k", "v", properties=[("p", "1")])
    .without_value("k")
  assert_eq(context.baggage_entry("k"), None)
  assert_eq(context.baggage_entries().length(), 0)
}

///|
test "baggage_entries_keeps_innermost_member_and_properties" {
  let context = @context.Context::root()
    .with_baggage_entry("a", "outer", properties=[("source", "outer")])
    .with_baggage_entry("b", "other")
    .with_baggage_entry("a", "inner", properties=[("source", "inner")])
  let entries = context.baggage_entries()
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].key, "a")
  assert_eq(entries[0].value, "inner")
  assert_eq(entries[0].properties, [("source", "inner")])
  assert_eq(entries[1].key, "b")
}
