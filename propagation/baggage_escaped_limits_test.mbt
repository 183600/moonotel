// Boundary coverage for the baggage byte budget when member values are
// percent-encoded. The W3C limit applies to the normalized `baggage` string,
// so an escape such as `%41` whose decoded character is legal costs one byte,
// while a reserved character such as `,` stays three bytes (`%2C`).

///|
fn escaped_baggage_value(escape : String, count : Int32) -> String {
  let sb = StringBuilder(size_hint=escape.length() * count)
  let mut i = 0
  while i < count {
    sb.write_string(escape)
    i = i + 1
  }
  sb.to_string()
}

///|
test "parse_baggage_budgets_escaped_values_by_normalized_size" {
  // The raw header is 9002 bytes, but `%41` normalizes to a one-byte `A`, so
  // the member occupies only 3002 bytes and must be kept.
  let header = "k=" + escaped_baggage_value("%41", 3000)
  assert_true(header.length() > @propagation.BAGGAGE_MAX_BYTES)
  let pairs = @propagation.parse_baggage(header)
  assert_eq(pairs.length(), 1)
  assert_eq(pairs[0].0, "k")
  assert_eq(pairs[0].1.length(), 3000)
  assert_eq(@propagation.format_baggage(pairs).length(), 3002)
}

///|
test "parse_baggage_drops_an_escaped_member_beyond_the_normalized_limit" {
  // 8190 `%41` escapes plus `k=` is exactly the 8192-byte normalized limit.
  let fits = "k=" + escaped_baggage_value("%41", 8190)
  let pairs = @propagation.parse_baggage(fits)
  assert_eq(pairs.length(), 1)
  assert_eq(pairs[0].1.length(), 8190)
  // One more escaped character exceeds the budget, so the member is dropped.
  let over = "k=" + escaped_baggage_value("%41", 8191)
  assert_eq(@propagation.parse_baggage(over), [])
}

///|
test "format_baggage_budgets_reserved_escaped_characters_as_three_bytes" {
  // A comma is reserved in a value and is written as `%2C`, so 2730 of them
  // occupy 8190 bytes: `k=` plus that is exactly the normalized limit.
  let fits = escaped_baggage_value(",", 2730)
  let header = @propagation.format_baggage([("k", fits)])
  assert_eq(header.length(), @propagation.BAGGAGE_MAX_BYTES)
  assert_eq(@propagation.parse_baggage(header), [("k", fits)])
  // 2731 commas need 8193 bytes and the member is dropped.
  let over = escaped_baggage_value(",", 2731)
  assert_eq(@propagation.format_baggage([("k", over)]), "")
}

///|
test "format_baggage_entries_budgets_escaped_property_values" {
  // `k=v;p=` plus 2728 commas (8184 escaped bytes) is 8190 bytes; two more
  // escaped commas would exceed the 8192-byte budget.
  let fits : Array[@propagation.BaggageEntry] = [
    @propagation.BaggageEntry::new("k", "v", properties=[
      ("p", escaped_baggage_value(",", 2728)),
    ]),
  ]
  let header = @propagation.format_baggage_entries(fits)
  assert_eq(header.length(), 8190)
  let over : Array[@propagation.BaggageEntry] = [
    @propagation.BaggageEntry::new("k", "v", properties=[
      ("p", escaped_baggage_value(",", 2731)),
    ]),
  ]
  assert_eq(@propagation.format_baggage_entries(over), "")
}
