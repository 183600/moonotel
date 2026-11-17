// W3C Trace Context Level 2 keys may start with a digit and contain `@`
// anywhere after the first character; keys are capped at 256 characters.

///|
fn level2_repeated_char(c : Char, count : Int32) -> String {
  let sb = StringBuilder(capacity=count * 2)
  for i = 0; i < count; i = i + 1 {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
test "tracestate_level_2_key_allowed_characters" {
  let key = "a_-*/@09z"
  let value = key + "=v"
  assert_eq(@propagation.parse_tracestate(value), Some(value))
  assert_eq(@propagation.Tracestate::parse(value).unwrap().get(key), Some("v"))
}

///|
test "tracestate_level_2_key_rejects_disallowed_characters" {
  for key in ["A", "a b", "a+b", "a?b", "a~b"] {
    assert_eq(@propagation.parse_tracestate(key + "=v"), None)
    assert_true(@propagation.Tracestate::parse(key + "=v") is None)
  }
}

///|
test "tracestate_level_2_key_length_boundary_with_multiple_at" {
  let at_limit = "a@" + level2_repeated_char('b', 252) + "@c"
  assert_eq(at_limit.length(), 256)
  assert_eq(@propagation.parse_tracestate(at_limit + "=v"), Some(at_limit + "=v"))
  let over_limit = at_limit + "c"
  assert_eq(over_limit.length(), 257)
  assert_eq(@propagation.parse_tracestate(over_limit + "=v"), None)
  assert_true(@propagation.Tracestate::parse(over_limit + "=v") is None)
}

///|
test "tracestate_level_2_mutations_accept_keys_with_at" {
  let ts = @propagation.Tracestate::parse("0=v").unwrap()
  let ts = ts.add("vendor@1system", "a")
  assert_eq(ts.to_header(), "vendor@1system=a,0=v")
  assert_eq(ts.get("vendor@1system"), Some("a"))
  let ts = ts.update("0", "changed")
  assert_eq(ts.to_header(), "0=changed,vendor@1system=a")
  let ts = ts.remove("vendor@1system")
  assert_eq(ts.to_header(), "0=changed")
}

///|
test "tracestate_parse_or_empty_keeps_level_2_keys" {
  let ts = @propagation.Tracestate::parse_or_empty("0=v,a@b@c=1")
  assert_eq(ts.length(), 2)
  assert_eq(ts.get("0"), Some("v"))
  assert_eq(ts.get("a@b@c"), Some("1"))
}
