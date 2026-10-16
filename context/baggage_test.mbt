// Tests for baggage values attached to a Context.

test "with_baggage_adds_all_values" {
  let values : Map[String, String] = Map([])
  values.set("a", "1")
  values.set("b", "2")
  let context = @context.Context::root().with_baggage(values)
  assert_eq(context.value("a"), Some("1"))
  assert_eq(context.value("b"), Some("2"))
  assert_eq(context.baggage().length(), 2)
}

test "with_baggage_overrides_existing_value" {
  let values : Map[String, String] = Map([])
  values.set("a", "2")
  let context = @context.Context::root().with_value("a", "1").with_baggage(values)
  assert_eq(context.value("a"), Some("2"))
}

test "with_baggage_does_not_mutate_the_source_map" {
  let values : Map[String, String] = Map([])
  values.set("a", "1")
  let context = @context.Context::root().with_baggage(values)
  values.set("b", "2")
  assert_eq(context.value("b"), None)
  assert_eq(context.baggage().length(), 1)
}

test "with_baggage_keeps_existing_values" {
  let values : Map[String, String] = Map([])
  values.set("b", "2")
  let context = @context.Context::root().with_value("a", "1").with_baggage(values)
  assert_eq(context.value("a"), Some("1"))
  assert_eq(context.value("b"), Some("2"))
}

test "without_value_hides_outer_values" {
  let context = @context.Context::root()
    .with_value("user.id", "42")
    .without_value("user.id")
  assert_eq(context.value("user.id"), None)
  assert_eq(context.baggage().length(), 0)
  assert_false(context.has_baggage())
}

test "without_value_keeps_other_keys" {
  let context = @context.Context::root()
    .with_value("a", "1")
    .with_value("b", "2")
    .without_value("a")
  assert_eq(context.value("a"), None)
  assert_eq(context.value("b"), Some("2"))
  assert_eq(context.baggage().length(), 1)
  assert_true(context.has_baggage())
}

test "without_value_can_be_overridden_again" {
  let context = @context.Context::root()
    .with_value("a", "1")
    .without_value("a")
    .with_value("a", "3")
  assert_eq(context.value("a"), Some("3"))
}

test "without_value_on_missing_key_is_noop" {
  let context = @context.Context::root().with_value("a", "1").without_value("b")
  assert_eq(context.value("a"), Some("1"))
  assert_eq(context.baggage().length(), 1)
}
