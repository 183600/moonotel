// Boundary tests for baggage properties: optional whitespace around keys and
// values, duplicate key-only flags, and the formatter's byte budget.

///|
test "baggage_properties_trim_ows_and_keep_the_first_key_only_flag" {
  let entries = @propagation.parse_baggage_entries(
    "a=1; flag ; p = v ; x ; x, b=2",
  )
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].key, "a")
  assert_eq(entries[0].value, "1")
  assert_eq(entries[0].properties, [
    ("flag", ""),
    ("p", "v"),
    ("x", ""),
  ])
  assert_eq(entries[1].key, "b")
  assert_eq(entries[1].value, "2")
  assert_eq(
    @propagation.format_baggage_entries(entries),
    "a=1;flag;p=v;x,b=2",
  )
}

///|
test "format_baggage_entries_drops_a_member_over_the_byte_budget" {
  let value = StringBuilder()
  let mut index = 0
  while index < 9000 {
    value.write_char('a')
    index = index + 1
  }
  let entries : Array[@propagation.BaggageEntry] = [
    @propagation.BaggageEntry::new("key", value.to_string()),
  ]
  assert_eq(@propagation.format_baggage_entries(entries), "")
}
