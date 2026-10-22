// Accessor and copy-on-write coverage for `ResourceAttributes`, the resource
// view carried by every `SpanData`. Mutating a snapshot must never change the
// provider's shared map.

///|
test "resource_attributes_accessors_read_the_shared_view" {
  let shared : Map[String, @sdk.AttributeValue] = Map([
    ("a", @sdk.AttributeValue::StringValue("1")),
    ("b", @sdk.AttributeValue::IntValue(2L)),
  ])
  let snapshot = @sdk.ResourceAttributes::new(shared)
  assert_false(snapshot.is_empty())
  assert_eq(snapshot.length(), 2)
  assert_eq(
    snapshot.get_or_default(
      "missing",
      @sdk.AttributeValue::StringValue("default"),
    ),
    @sdk.AttributeValue::StringValue("default"),
  )
  assert_eq(
    snapshot.get_or_default("a", @sdk.AttributeValue::StringValue("default")),
    @sdk.AttributeValue::StringValue("1"),
  )
  let keys : Array[String] = []
  for key in snapshot.keys() {
    keys.push(key)
  }
  assert_eq(keys.length(), 2)
  assert_true(keys.contains("a"))
  assert_true(keys.contains("b"))
  let values : Array[@sdk.AttributeValue] = []
  for value in snapshot.values() {
    values.push(value)
  }
  assert_eq(values.length(), 2)
  let pairs = snapshot.to_array()
  assert_eq(pairs.length(), 2)
  for pair in pairs {
    assert_true(shared.contains(pair.0))
  }
}

///|
test "resource_attributes_remove_copies_the_shared_map" {
  let shared : Map[String, @sdk.AttributeValue] = Map([
    ("a", @sdk.AttributeValue::StringValue("1")),
    ("b", @sdk.AttributeValue::BoolValue(true)),
  ])
  let snapshot = @sdk.ResourceAttributes::new(shared)
  snapshot.remove("a")
  assert_eq(snapshot.get("a"), None)
  assert_eq(snapshot.get("b"), Some(@sdk.AttributeValue::BoolValue(true)))
  assert_eq(
    shared.get("a"),
    Some(@sdk.AttributeValue::StringValue("1")),
  )
  assert_false(snapshot.is_empty())
  snapshot.remove("b")
  assert_true(snapshot.is_empty())
  assert_false(shared.is_empty())
}

///|
test "resource_attributes_clear_copies_the_shared_map" {
  let shared : Map[String, @sdk.AttributeValue] = Map([
    ("a", @sdk.AttributeValue::StringValue("1")),
  ])
  let snapshot = @sdk.ResourceAttributes::new(shared)
  snapshot.clear()
  assert_true(snapshot.is_empty())
  assert_eq(
    shared.get("a"),
    Some(@sdk.AttributeValue::StringValue("1")),
  )
}

///|
test "resource_attributes_own_map_wins_over_shared_values" {
  let shared : Map[String, @sdk.AttributeValue] = Map([
    ("a", @sdk.AttributeValue::StringValue("shared")),
  ])
  let snapshot = @sdk.ResourceAttributes::new(shared)
  snapshot.set("a", @sdk.AttributeValue::StringValue("own"))
  snapshot.set("b", @sdk.AttributeValue::IntValue(3L))
  assert_eq(
    snapshot.get("a"),
    Some(@sdk.AttributeValue::StringValue("own")),
  )
  assert_eq(snapshot.get("b"), Some(@sdk.AttributeValue::IntValue(3L)))
  assert_eq(
    shared.get("a"),
    Some(@sdk.AttributeValue::StringValue("shared")),
  )
  assert_false(shared.contains("b"))
  snapshot.remove("a")
  assert_eq(snapshot.get("a"), None)
  assert_eq(
    shared.get("a"),
    Some(@sdk.AttributeValue::StringValue("shared")),
  )
}
