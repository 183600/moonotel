// Edge cases of the first-class `Tracestate` parser: malformed members are
// rejected, the best-effort `parse_or_empty` variant falls back to the empty
// list, and optional whitespace before `=` is not part of the key or value.

///|
test "tracestate_parse_rejects_a_member_without_equals" {
  assert_true(@propagation.Tracestate::parse("no_equals") is None)
  assert_true(@propagation.Tracestate::parse("a=1,no_equals") is None)
}

///|
test "tracestate_parse_or_empty_discards_an_invalid_value" {
  assert_true(@propagation.Tracestate::parse_or_empty("no_equals").is_empty())
  assert_true(@propagation.Tracestate::parse_or_empty("Key=value").is_empty())
}

///|
test "tracestate_parse_or_empty_keeps_a_valid_value" {
  let state = @propagation.Tracestate::parse_or_empty("a=1,b=2")
  assert_eq(state.length(), 2)
  assert_eq(state.get("a"), Some("1"))
  assert_eq(state.to_header(), "a=1,b=2")
}

///|
test "tracestate_parse_trims_value_after_whitespace_before_equals" {
  // `key = value` is the W3C `key OWS "=" OWS value` form: the optional
  // whitespace on both sides of `=` is not part of either component.
  let state = @propagation.Tracestate::parse("a = 1, b = two").unwrap()
  assert_eq(state.get("a"), Some("1"))
  assert_eq(state.get("b"), Some("two"))
  assert_eq(state.to_header(), "a=1,b=two")
}

///|
test "tracestate_parse_keeps_blanks_after_equals_without_before_whitespace" {
  // Without whitespace before `=`, a blank after `=` is part of the value,
  // matching `parse_tracestate` and the round trip through the header.
  let state = @propagation.Tracestate::parse("a= v").unwrap()
  assert_eq(state.get("a"), Some(" v"))
  assert_eq(state.to_header(), "a= v")
}
