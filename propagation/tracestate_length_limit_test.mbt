// Boundary behavior of the W3C tracestate 512-character recommendation:
// whole entries are dropped (entries longer than 128 characters first, then
// entries from the end), never split.

///|
fn length_limit_repeated(c : Char, count : Int32) -> String {
  let sb = StringBuilder(size_hint=count * 2)
  for i = 0; i < count; i = i + 1 {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
fn length_limit_entry(key : String, value_length : Int32) -> String {
  key + "=" + length_limit_repeated('v', value_length)
}

///|
fn length_limit_join(entries : Array[String]) -> String {
  let sb = StringBuilder()
  for i, entry in entries {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_string(entry)
  }
  sb.to_string()
}

///|
test "tracestate_exactly_512_characters_is_preserved" {
  let header = length_limit_join([
    length_limit_entry("k0", 97),
    length_limit_entry("k1", 97),
    length_limit_entry("k2", 97),
    length_limit_entry("k3", 97),
    length_limit_entry("k4", 105),
  ])
  assert_eq(header.length(), 512)
  let state = @propagation.Tracestate::parse(header).unwrap()
  assert_eq(state.length(), 5)
  assert_eq(state.to_header(), header)
  assert_eq(@propagation.parse_tracestate(header), Some(header))
}

///|
test "tracestate_parse_drops_a_trailing_entry_when_over_512" {
  let header = length_limit_join([
    length_limit_entry("k0", 97),
    length_limit_entry("k1", 97),
    length_limit_entry("k2", 97),
    length_limit_entry("k3", 97),
    length_limit_entry("k4", 106),
  ])
  assert_eq(header.length(), 513)
  let state = @propagation.Tracestate::parse(header).unwrap()
  assert_eq(state.length(), 4)
  assert_eq(state.get("k4"), None)
  let truncated = state.to_header()
  assert_eq(truncated.length(), 403)
  assert_eq(@propagation.parse_tracestate(header), Some(truncated))
}

///|
test "tracestate_truncation_removes_a_large_entry_before_short_tails" {
  let header = length_limit_join([
    length_limit_entry("s1", 117),
    length_limit_entry("big", 125),
    length_limit_entry("s2", 117),
    length_limit_entry("s3", 117),
  ])
  assert_eq(header.length(), 492)
  let state = @propagation.Tracestate::parse(header).unwrap()
  assert_eq(state.length(), 4)
  let state = state.add("new", length_limit_repeated('w', 50))
  // The 129-character `big` entry is removed first; the short `s3` tail
  // survives even though dropping it alone would also fit under 512.
  assert_eq(state.get("big"), None)
  assert_eq(state.get("new"), Some(length_limit_repeated('w', 50)))
  assert_eq(state.get("s3"), Some(length_limit_repeated('v', 117)))
  assert_eq(state.length(), 4)
  assert_eq(state.to_header().length(), 417)
}

///|
test "inject_truncates_a_long_context_tracestate" {
  let header = length_limit_join([
    length_limit_entry("k0", 97),
    length_limit_entry("k1", 97),
    length_limit_entry("k2", 97),
    length_limit_entry("k3", 97),
    length_limit_entry("k4", 97),
    length_limit_entry("k5", 97),
  ])
  assert_eq(header.length(), 605)
  let sc = @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    1,
    tracestate=header,
  )
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject(sc, carrier)
  let propagated = carrier.get("tracestate").unwrap()
  assert_eq(propagated.length(), 504)
  assert_eq(propagated, @propagation.parse_tracestate(header).unwrap())
  assert_eq(
    carrier.get("traceparent"),
    Some("00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"),
  )
}

///|
test "tracestate_add_drops_rightmost_entries_to_stay_within_512" {
  let header = length_limit_join([
    length_limit_entry("k0", 97),
    length_limit_entry("k1", 97),
    length_limit_entry("k2", 97),
    length_limit_entry("k3", 97),
    length_limit_entry("k4", 97),
  ])
  assert_eq(header.length(), 504)
  let state = @propagation.Tracestate::parse(header).unwrap()
  let value = length_limit_repeated('w', 50)
  let state = state.add("new", value)
  assert_eq(state.length(), 5)
  assert_eq(state.get("new"), Some(value))
  assert_eq(state.get("k4"), None)
  assert_eq(state.get("k0"), Some(length_limit_repeated('v', 97)))
  assert_eq(state.to_header().length(), 458)
}

///|
test "tracestate_update_drops_rightmost_entries_to_stay_within_512" {
  let header = length_limit_join([
    length_limit_entry("k0", 97),
    length_limit_entry("k1", 97),
    length_limit_entry("k2", 97),
    length_limit_entry("k3", 97),
    length_limit_entry("k4", 97),
  ])
  let state = @propagation.Tracestate::parse(header).unwrap()
  let value = length_limit_repeated('w', 124)
  let state = state.update("k0", value)
  assert_eq(state.length(), 4)
  assert_eq(state.get("k0"), Some(value))
  assert_eq(state.get("k4"), None)
  assert_eq(state.get("k1"), Some(length_limit_repeated('v', 97)))
  assert_eq(state.to_header().length(), 430)
}
