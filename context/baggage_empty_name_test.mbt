// The OpenTelemetry Baggage API requires baggage names to be non-empty. An
// empty name is not a baggage entry, so setters and removals must ignore it
// instead of storing an entry that cannot be propagated.

///|
test "with_value ignores an empty baggage name" {
  let context = @context.Context::root().with_value("", "value")
  assert_false(context.has_baggage())
  assert_eq(context.value(""), None)
  assert_eq(context.baggage_entry(""), None)
  assert_eq(context.baggage().length(), 0)
  assert_eq(context.baggage_entries().length(), 0)
}

///|
test "empty_with_value does not hide an outer value" {
  let context = @context.Context::root()
    .with_value("user.id", "42")
    .with_value("", "ignored")
  assert_true(context.has_baggage())
  assert_eq(context.value("user.id"), Some("42"))
  assert_eq(context.baggage().length(), 1)
}

///|
test "with_baggage_entry ignores an empty name" {
  let context = @context.Context::root()
    .with_baggage_entry("", "value", properties=[("p", "1")])
  assert_false(context.has_baggage())
  assert_eq(context.baggage_entries().length(), 0)
}

///|
test "without_value ignores an empty name" {
  let context = @context.Context::root()
    .with_value("user.id", "42")
    .without_value("")
  // The no-op removal must neither delete the value nor install a marker that
  // would hide it.
  assert_eq(context.value("user.id"), Some("42"))
  assert_eq(context.baggage().get("user.id"), Some("42"))
}

///|
test "with_baggage skips empty names and keeps valid ones" {
  let values : Map[String, String] = Map([
    ("", "ignored"),
    ("user.id", "42"),
    ("tenant", "acme"),
  ])
  let context = @context.Context::root().with_baggage(values)
  assert_eq(context.value(""), None)
  assert_eq(context.value("user.id"), Some("42"))
  assert_eq(context.value("tenant"), Some("acme"))
  assert_eq(context.baggage().length(), 2)
  assert_eq(context.baggage_entries().length(), 2)
}

///|
test "with_baggage with only empty names does not clear outer baggage" {
  let values : Map[String, String] = Map([("", "ignored")])
  let context = @context.Context::root()
    .with_value("user.id", "42")
    .with_baggage(values)
  // An update carrying no valid entry is a no-op, unlike an empty map, which
  // explicitly clears the baggage.
  assert_eq(context.value("user.id"), Some("42"))
  assert_true(context.has_baggage())
}

///|
test "with_baggage_owned skips empty names" {
  let values : Map[String, String] = Map([
    ("", "ignored"),
    ("user.id", "42"),
  ])
  let context = @context.Context::root().with_baggage_owned(values)
  assert_eq(context.value("user.id"), Some("42"))
  assert_eq(context.value(""), None)
  let only_empty : Map[String, String] = Map([("", "ignored")])
  let unchanged = @context.Context::root()
    .with_value("user.id", "42")
    .with_baggage_owned(only_empty)
  assert_eq(unchanged.value("user.id"), Some("42"))
}

///|
test "with_baggage_entries skips empty names" {
  let entries : Array[@context.BaggageEntry] = [
    @context.BaggageEntry::new("", "ignored", properties=[("p", "1")]),
    @context.BaggageEntry::new("user.id", "42", properties=[("tenant", "a")]),
  ]
  let context = @context.Context::root().with_baggage_entries(entries)
  assert_eq(context.value(""), None)
  assert_eq(context.value("user.id"), Some("42"))
  let entry = context.baggage_entry("user.id").unwrap()
  assert_eq(entry.properties.length(), 1)
  assert_eq(entry.properties[0].0, "tenant")
  assert_eq(entry.properties[0].1, "a")
}

///|
test "with_baggage_entries with only empty names does not clear outer baggage" {
  let entries : Array[@context.BaggageEntry] = [
    @context.BaggageEntry::new("", "ignored"),
  ]
  let context = @context.Context::root()
    .with_value("user.id", "42")
    .with_baggage_entries(entries)
  assert_eq(context.value("user.id"), Some("42"))
  assert_true(context.has_baggage())
}

///|
test "an empty entries array still clears outer baggage" {
  let context = @context.Context::root()
    .with_value("user.id", "42")
    .with_baggage_entries([])
  assert_eq(context.value("user.id"), None)
  assert_false(context.has_baggage())
}
