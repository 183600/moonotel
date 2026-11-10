// W3C Trace Context Level 2 key grammar: `key = (lcalpha / DIGIT) 0*255 keychar`
// where `keychar` includes `@`. Keys are limited to 256 characters regardless
// of whether they contain `@`.

///|
fn repeated_char(c : Char, count : Int32) -> String {
  let sb = StringBuilder(size_hint=count * 2)
  for i = 0; i < count; i = i + 1 {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
test "parse_tracestate_accepts_a_max_length_key_with_at" {
  let key = repeated_char('a', 250) + "@" + repeated_char('b', 5)
  assert_eq(key.length(), 256)
  let value = key + "=v"
  assert_eq(@propagation.parse_tracestate(value), Some(value))
  assert_eq(@propagation.Tracestate::parse(value).unwrap().get(key), Some("v"))
}

///|
test "parse_tracestate_accepts_a_digit_led_key_ending_with_at" {
  let key = "1" + repeated_char('a', 254) + "@"
  assert_eq(key.length(), 256)
  let value = key + "=v"
  assert_eq(@propagation.parse_tracestate(value), Some(value))
  assert_true(@propagation.Tracestate::parse(value) is Some(_))
}

///|
test "parse_tracestate_rejects_a_key_beyond_the_limit_with_at" {
  let key = repeated_char('a', 241) + "@" + repeated_char('b', 15)
  assert_eq(key.length(), 257)
  assert_eq(@propagation.parse_tracestate(key + "=v"), None)
  assert_true(@propagation.Tracestate::parse(key + "=v") is None)
}

///|
test "parse_tracestate_rejects_a_key_beyond_the_limit_without_at" {
  let key = repeated_char('k', 257)
  assert_eq(@propagation.parse_tracestate(key + "=v"), None)
  assert_true(@propagation.Tracestate::parse(key + "=v") is None)
}

///|
test "parse_tracestate_rejects_an_overlong_key_with_multiple_at" {
  let key = repeated_char('a', 241) + "@" + repeated_char('b', 15) + "@c"
  assert_eq(key.length(), 259)
  assert_eq(@propagation.parse_tracestate(key + "=v"), None)
  assert_true(@propagation.Tracestate::parse(key + "=v") is None)
}

///|
test "tracestate_mutation_accepts_a_max_length_key_with_at" {
  let key = repeated_char('a', 250) + "@" + repeated_char('b', 5)
  let state = @propagation.Tracestate::parse("a=1").unwrap().add(key, "v")
  assert_eq(state.get(key), Some("v"))
  assert_eq(state.to_header(), key + "=v,a=1")
}

///|
test "tracestate_mutation_rejects_a_key_beyond_the_limit" {
  let key = repeated_char('a', 241) + "@" + repeated_char('b', 15)
  let state = @propagation.Tracestate::parse("a=1").unwrap().add(key, "v")
  assert_eq(state.to_header(), "a=1")
  assert_eq(state.get(key), None)
}
