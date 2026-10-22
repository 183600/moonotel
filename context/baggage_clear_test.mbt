// Clearing all baggage from a context. Empty baggage updates and the explicit
// `without_baggage` marker must hide values stored in outer contexts.

///|
test "empty_with_baggage_clears_outer_values" {
  let context = @context.Context::root()
    .with_value("a", "1")
    .with_value("b", "2")
    .with_baggage(Map([]))
  assert_eq(context.value("a"), None)
  assert_eq(context.value("b"), None)
  assert_eq(context.baggage().length(), 0)
  assert_eq(context.baggage_entries().length(), 0)
  assert_eq(context.baggage_entry("a"), None)
  assert_false(context.has_baggage())
}

///|
test "without_baggage_clears_and_allows_new_values" {
  let context = @context.Context::root()
    .with_value("secret", "s")
    .without_baggage()
    .with_value("public", "p")
  assert_eq(context.value("secret"), None)
  assert_eq(context.value("public"), Some("p"))
  assert_eq(context.baggage().length(), 1)
  assert_eq(context.baggage().get("public"), Some("p"))
  assert_eq(context.baggage_entry("secret"), None)
  assert_true(context.has_baggage())
}

///|
test "empty_baggage_entries_and_owned_maps_clear_too" {
  let entries_context = @context.Context::root()
    .with_value("a", "1")
    .with_baggage_entries([])
  assert_eq(entries_context.value("a"), None)
  let owned_context = @context.Context::root()
    .with_value("b", "2")
    .with_baggage_owned(Map([]))
  assert_eq(owned_context.value("b"), None)
}

///|
test "with_baggage_from_preserves_a_clear_marker" {
  let cleared = @context.Context::root()
    .with_value("old", "1")
    .with_value("kept", "2")
    .without_baggage()
    .with_value("new", "3")
  let merged = @context.Context::root()
    .with_value("old", "outer")
    .with_value("kept", "outer")
    .with_baggage_from(cleared)
  assert_eq(merged.value("old"), None)
  assert_eq(merged.value("kept"), None)
  assert_eq(merged.value("new"), Some("3"))
}
