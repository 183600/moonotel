// Baggage chain edge cases: values from an outer node are hidden by an inner
// removal marker, and the ordered-entry APIs keep the innermost member of a
// duplicated key.

///|
test "with_baggage_owned_accepts_a_valid_map" {
  let context = @context.Context::root().with_baggage_owned(
    Map([("a", "1"), ("b", "2")]),
  )
  assert_eq(context.value("a"), Some("1"))
  assert_eq(context.value("b"), Some("2"))
  assert_eq(context.baggage_entries().length(), 2)
}

///|
test "baggage_entry_skips_a_missing_baggage_map_key" {
  let context = @context.Context::root()
    .with_baggage(Map([("a", "1")]))
    .with_value("b", "2")
  assert_eq(context.baggage_entry("missing"), None)
  assert_eq(context.value("a"), Some("1"))
  assert_eq(context.value("b"), Some("2"))
}

///|
test "inner_entries_hide_an_outer_entry_with_the_same_key" {
  let base = @context.Context::root().with_baggage_entries([
    @context.BaggageEntry::new("a", "outer"),
  ])
  let context = base.with_baggage_entries([
    @context.BaggageEntry::new("a", "inner"),
    @context.BaggageEntry::new("b", "inner"),
  ])
  let entries = context.baggage_entries()
  assert_eq(entries.length(), 2)
  let mut saw_a = false
  let mut saw_b = false
  for entry in entries {
    if entry.key == "a" {
      assert_eq(entry.value, "inner")
      saw_a = true
    } else if entry.key == "b" {
      assert_eq(entry.value, "inner")
      saw_b = true
    }
  }
  assert_true(saw_a)
  assert_true(saw_b)
  assert_eq(context.value("a"), Some("inner"))
}

///|
test "a_removal_hides_an_outer_entry_with_the_same_key" {
  let base = @context.Context::root().with_baggage_entries([
    @context.BaggageEntry::new("a", "outer"),
  ])
  let context = base.without_value("a").with_baggage_entries([
    @context.BaggageEntry::new("b", "inner"),
  ])
  let entries = context.baggage_entries()
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].key, "b")
  assert_eq(context.value("a"), None)
  assert_eq(context.value("b"), Some("inner"))
}

///|
test "a_removal_hides_an_outer_map_value_from_has_baggage_and_baggage" {
  let context = @context.Context::root()
    .with_baggage(Map([("a", "1")]))
    .without_value("a")
  assert_false(context.has_baggage())
  assert_eq(context.baggage().length(), 0)
  assert_eq(context.baggage_entries().length(), 0)
  assert_eq(context.value("a"), None)
}
