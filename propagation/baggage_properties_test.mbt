// Blackbox tests for W3C Baggage member properties (`key=value;prop=v`).

///|
test "baggage_entry_new_defaults_to_no_properties" {
  let entry = @propagation.BaggageEntry::new("k", "v")
  assert_eq(entry.key, "k")
  assert_eq(entry.value, "v")
  assert_eq(entry.properties, [])
}

///|
test "parse_baggage_entries_keeps_properties" {
  let entries = @propagation.parse_baggage_entries("a=1;prop=2;x=y%20z")
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].key, "a")
  assert_eq(entries[0].value, "1")
  assert_eq(entries[0].properties, [("prop", "2"), ("x", "y z")])
}

///|
test "parse_baggage_entries_trims_ows_around_properties" {
  let entries = @propagation.parse_baggage_entries("a = 1 ; p = v ; q=2")
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].key, "a")
  assert_eq(entries[0].value, "1")
  assert_eq(entries[0].properties, [("p", "v"), ("q", "2")])
}

///|
test "parse_baggage_entries_skips_malformed_properties" {
  let entries = @propagation.parse_baggage_entries(
    "a=1;flag;bad key=2;p=va\"lue;ok=3",
  )
  assert_eq(entries.length(), 1)
  // `;flag` is a valid key-only property (W3C `property =/ key OWS`); the
  // properties with an invalid key or value are still skipped.
  assert_eq(entries[0].properties, [("flag", ""), ("ok", "3")])
}

///|
test "format_baggage_entries_emits_key_only_properties" {
  let entries : Array[@propagation.BaggageEntry] = [
    @propagation.BaggageEntry::new("k", "v", properties=[
      ("flag", ""),
      ("p", "1"),
    ]),
  ]
  assert_eq(@propagation.format_baggage_entries(entries), "k=v;flag;p=1")
  let reparsed = @propagation.parse_baggage_entries("k=v;flag;p=1")
  assert_eq(reparsed.length(), 1)
  assert_eq(reparsed[0].properties, [("flag", ""), ("p", "1")])
}

///|
test "parse_baggage_entries_drops_duplicate_property_keys" {
  let entries = @propagation.parse_baggage_entries("a=1;p=1;p=2")
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].properties, [("p", "1")])
}

///|
test "parse_baggage_entries_keeps_members_after_invalid_properties" {
  let entries = @propagation.parse_baggage_entries("a=1;=,b=2")
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].key, "a")
  assert_eq(entries[0].properties, [])
  assert_eq(entries[1].key, "b")
}

///|
test "format_baggage_entries_round_trips_properties" {
  let entries : Array[@propagation.BaggageEntry] = [
    @propagation.BaggageEntry::new("a", "1", properties=[("p", "x y")]),
    @propagation.BaggageEntry::new("b", "2"),
  ]
  let header = @propagation.format_baggage_entries(entries)
  assert_eq(header, "a=1;p=x%20y,b=2")
  let reparsed = @propagation.parse_baggage_entries(header)
  assert_eq(reparsed.length(), 2)
  assert_eq(reparsed[0].key, "a")
  assert_eq(reparsed[0].value, "1")
  assert_eq(reparsed[0].properties, [("p", "x y")])
  assert_eq(reparsed[1].key, "b")
  assert_eq(reparsed[1].properties, [])
}

///|
test "format_baggage_entries_skips_invalid_and_duplicate_properties" {
  let entries : Array[@propagation.BaggageEntry] = [
    @propagation.BaggageEntry::new("a", "1", properties=[
      ("p", "1"),
      ("p", "2"),
      ("bad key", "3"),
      ("q", "4"),
    ]),
  ]
  assert_eq(@propagation.format_baggage_entries(entries), "a=1;p=1;q=4")
}

///|
test "format_baggage_entries_skips_invalid_keys" {
  let entries : Array[@propagation.BaggageEntry] = [
    @propagation.BaggageEntry::new("bad key", "v", properties=[("p", "1")]),
    @propagation.BaggageEntry::new("ok", "v"),
  ]
  assert_eq(@propagation.format_baggage_entries(entries), "ok=v")
}

///|
test "format_baggage_entries_empty_is_empty" {
  assert_eq(@propagation.format_baggage_entries([]), "")
}

///|
test "baggage_properties_count_towards_the_byte_budget" {
  let value = StringBuilder()
  let mut i = 0
  while i < 8186 {
    value.write_char('x')
    i = i + 1
  }
  // `a=1;p=` plus the 8186-byte property value is exactly 8192 bytes.
  let fits = @propagation.parse_baggage_entries("a=1;p=" + value.to_string())
  assert_eq(fits.length(), 1)
  assert_eq(fits[0].properties.length(), 1)
  // One byte more exceeds the budget, and the member is dropped whole.
  assert_eq(
    @propagation.parse_baggage_entries("a=1;p=" + value.to_string() + "x"),
    [],
  )
}

///|
test "format_baggage_entries_emits_at_most_64_members" {
  let entries : Array[@propagation.BaggageEntry] = []
  let mut i = 0
  while i < 100 {
    entries.push(
      @propagation.BaggageEntry::new(
        "k" + i.to_string(),
        i.to_string(),
        properties=[("p", "v")],
      ),
    )
    i = i + 1
  }
  let header = @propagation.format_baggage_entries(entries)
  let reparsed = @propagation.parse_baggage_entries(header)
  assert_eq(reparsed.length(), @propagation.BAGGAGE_MAX_MEMBERS)
  assert_eq(reparsed[0].properties, [("p", "v")])
  assert_eq(reparsed[63].key, "k63")
}

///|
test "inject_and_extract_baggage_entries_round_trip" {
  let entries : Array[@propagation.BaggageEntry] = [
    @propagation.BaggageEntry::new("user.id", "42", properties=[("ttl", "1")]),
    @propagation.BaggageEntry::new("note", "a,b"),
  ]
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_baggage_entries(entries, carrier)
  assert_eq(
    carrier.get(@propagation.baggage_header_name()),
    Some("user.id=42;ttl=1,note=a%2Cb"),
  )
  let restored = @propagation.extract_baggage_entries(carrier)
  assert_eq(restored.length(), 2)
  assert_eq(restored[0].key, "user.id")
  assert_eq(restored[0].properties, [("ttl", "1")])
  assert_eq(restored[1].value, "a,b")
  // The pair-level API still drops properties.
  assert_eq(@propagation.extract_baggage(carrier).length(), 2)
}

///|
test "inject_baggage_entries_omits_an_empty_header" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_baggage_entries([], carrier)
  assert_eq(carrier.length(), 0)
  let invalid : Array[@propagation.BaggageEntry] = [
    @propagation.BaggageEntry::new("bad key", "v"),
  ]
  @propagation.inject_baggage_entries(invalid, carrier)
  assert_eq(carrier.length(), 0)
}

///|
test "extract_baggage_entries_missing_header" {
  let carrier = @propagation.TextMapCarrier::new()
  assert_eq(@propagation.extract_baggage_entries(carrier).length(), 0)
}
