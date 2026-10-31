// W3C Trace Context Level 2 key grammar: keys up to 256 characters are
// simple keys, while longer keys must be valid multi-tenant keys (tenant-id
// "@" system-id). The two segments have their own length limits.

///|
fn repeated_char(c : Char, count : Int) -> String {
  let sb = StringBuilder(size_hint=count * 2)
  for i = 0; i < count; i = i + 1 {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
test "parse_tracestate_accepts_a_max_length_multi_tenant_key" {
  let key = repeated_char('a', 241) + "@" + repeated_char('b', 256)
  assert_eq(key.length(), 498)
  let value = key + "=v"
  assert_eq(@propagation.parse_tracestate(value), Some(value))
  assert_eq(@propagation.Tracestate::parse(value).unwrap().get(key), Some("v"))
}

///|
test "parse_tracestate_rejects_a_multi_tenant_key_beyond_the_limit" {
  let key = repeated_char('a', 241) + "@" + repeated_char('b', 257)
  assert_eq(key.length(), 499)
  assert_eq(@propagation.parse_tracestate(key + "=v"), None)
  assert_true(@propagation.Tracestate::parse(key + "=v") is None)
}

///|
test "parse_tracestate_rejects_an_overlong_tenant_id" {
  let key = repeated_char('a', 242) + "@" + repeated_char('b', 256)
  assert_eq(key.length(), 499)
  assert_eq(@propagation.parse_tracestate(key + "=v"), None)
  assert_true(@propagation.Tracestate::parse(key + "=v") is None)
}

///|
test "parse_tracestate_rejects_overlong_keys_without_a_single_at" {
  let key = repeated_char('k', 257)
  assert_eq(@propagation.parse_tracestate(key + "=v"), None)
  let multiple = repeated_char('a', 241) + "@" + repeated_char('b', 15) + "@c"
  assert_eq(multiple.length(), 259)
  assert_eq(@propagation.parse_tracestate(multiple + "=v"), None)
}

///|
test "parse_tracestate_validates_the_multi_tenant_system_id" {
  let digit_system = repeated_char('a', 241) + "@" + "1" + repeated_char('b', 249)
  assert_eq(digit_system.length(), 492)
  assert_eq(@propagation.parse_tracestate(digit_system + "=v"), None)
  let at_after_at = repeated_char('a', 241) + "@@" + repeated_char('b', 15)
  assert_eq(@propagation.parse_tracestate(at_after_at + "=v"), None)
}

///|
test "parse_tracestate_accepts_a_long_multi_tenant_key_from_a_mutation" {
  let key = repeated_char('a', 241) + "@" + repeated_char('b', 256)
  let state = @propagation.Tracestate::parse("a=1").unwrap().add(key, "v")
  assert_eq(state.get(key), Some("v"))
  assert_eq(state.to_header(), key + "=v,a=1")
}

///|
test "parse_tracestate_still_treats_short_at_keys_as_simple_keys" {
  // A 256-character key containing `@` is a valid simple key regardless of
  // how the two sides compare to the multi-tenant segment limits.
  let key = repeated_char('a', 250) + "@" + repeated_char('b', 5)
  assert_eq(key.length(), 256)
  let value = key + "=v"
  assert_eq(@propagation.parse_tracestate(value), Some(value))
}
