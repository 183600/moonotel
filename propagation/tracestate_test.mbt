// Blackbox tests for W3C `tracestate` parsing and propagation.

///|
fn tracestate_test_context() -> @api.SpanContext {
  @api.span_context(
    [
      0x4b, 0xf9, 0x2f, 0x35, 0x9d, 0x1e, 0x75, 0xb7, 0x61, 0x8a, 0x2d, 0x1f, 0x3c,
      0x4e, 0x5a, 0x6b,
    ],
    [0x00, 0xf0, 0x67, 0xaa, 0x0b, 0xa9, 0x02, 0xb7],
    1,
  )
}

///|
test "parse_tracestate_accepts_simple_members" {
  assert_eq(
    @propagation.parse_tracestate("congo=t61rcWkgMzE,rojo=00f067aa0ba902b7"),
    Some("congo=t61rcWkgMzE,rojo=00f067aa0ba902b7"),
  )
}

///|
test "parse_tracestate_trims_surrounding_whitespace" {
  assert_eq(@propagation.parse_tracestate("a=1 , b=2"), Some("a=1,b=2"))
  assert_eq(@propagation.parse_tracestate("a = 1"), Some("a=1"))
}

///|
test "parse_tracestate_accepts_multi_tenant_keys" {
  assert_eq(@propagation.parse_tracestate("foo@bar=baz"), Some("foo@bar=baz"))
  assert_eq(@propagation.parse_tracestate("1a@b=c"), Some("1a@b=c"))
  // Level 2 permits a digit as the first character and `@` anywhere after it.
  assert_eq(@propagation.parse_tracestate("0=v"), Some("0=v"))
  assert_eq(@propagation.parse_tracestate("a@1=v"), Some("a@1=v"))
  assert_eq(@propagation.parse_tracestate("a@b@c=1"), Some("a@b@c=1"))
  assert_eq(@propagation.parse_tracestate("a@=1"), Some("a@=1"))
}

///|
test "parse_tracestate_accepts_empty_members" {
  assert_eq(@propagation.parse_tracestate(""), None)
  assert_eq(@propagation.parse_tracestate("a=1,"), Some("a=1"))
  assert_eq(@propagation.parse_tracestate(",a=1"), Some("a=1"))
  assert_eq(@propagation.parse_tracestate("a=1, ,b=2"), Some("a=1,b=2"))
  let ts = @propagation.Tracestate::parse("a=1,").unwrap()
  assert_eq(ts.length(), 1)
  assert_eq(ts.get("a"), Some("1"))
}

///|
test "parse_tracestate_rejects_malformed_members" {
  assert_eq(@propagation.parse_tracestate("no_equals"), None)
  assert_eq(@propagation.parse_tracestate("=value"), None)
  assert_eq(@propagation.parse_tracestate("Key=value"), None)
  assert_eq(@propagation.parse_tracestate("a=b=c"), None)
}

///|
test "parse_tracestate_keeps_first_duplicate_key" {
  assert_eq(@propagation.parse_tracestate("a=1,a=2"), Some("a=1"))
  let ts = @propagation.Tracestate::parse("a=1,a=2").unwrap()
  assert_eq(ts.length(), 1)
  assert_eq(ts.get("a"), Some("1"))
}

///|
test "parse_tracestate_rejects_invalid_keys" {
  assert_eq(@propagation.parse_tracestate("@b=1"), None)
  assert_eq(@propagation.parse_tracestate("@=1"), None)
  assert_eq(@propagation.parse_tracestate("a@B=1"), None)
  assert_eq(@propagation.parse_tracestate("a b=1"), None)
}

///|
test "parse_tracestate_rejects_too_many_members" {
  let mut state = "k0=v"
  for i = 1; i < 33; i = i + 1 {
    state = state + ",k" + i.to_string() + "=v"
  }
  assert_eq(@propagation.parse_tracestate(state), None)
}

///|
test "parse_tracestate_does_not_count_empty_members_toward_limit" {
  let mut state = "k0=v"
  for i = 1; i < 32; i = i + 1 {
    state = state + ",k" + i.to_string() + "=v"
  }
  assert_eq(@propagation.parse_tracestate(state + ","), Some(state))
  assert_eq(@propagation.parse_tracestate("," + state), Some(state))
  assert_eq(@propagation.parse_tracestate(state + ", ,"), Some(state))
  let ts = @propagation.Tracestate::parse(state + ",").unwrap()
  assert_eq(ts.length(), 32)
  let too_many = state + ",k32=v"
  assert_eq(@propagation.parse_tracestate(too_many), None)
  assert_true(@propagation.Tracestate::parse(too_many) is None)
}

///|
test "tracestate_mutations_reject_trailing_blank_values" {
  let ts = @propagation.Tracestate::parse("a=1").unwrap()
  assert_eq(ts.add("b", "v ").to_header(), "a=1")
  assert_eq(ts.update("a", "x ").to_header(), "a=1")
  assert_eq(ts.add("b", " v").to_header(), "b= v,a=1")
}

///|
test "parse_preserves_blanks_after_equals" {
  assert_eq(@propagation.parse_tracestate("a=1,b= v"), Some("a=1,b= v"))
  assert_eq(@propagation.parse_tracestate(" a=1,b= v "), Some("a=1,b= v"))
  assert_eq(@propagation.parse_tracestate("a = v"), Some("a=v"))
  let ts = @propagation.Tracestate::parse("b= v").unwrap()
  assert_eq(ts.get("b"), Some(" v"))
  assert_eq(ts.add("z", " v").to_header(), "z= v,b= v")
  assert_eq(
    @propagation.Tracestate::parse(ts.add("z", " v").to_header())
      .unwrap()
      .get("z"),
    Some(" v"),
  )
}

///|
test "inject_writes_tracestate_from_span_context" {
  let sc = tracestate_test_context().with_tracestate("congo=t61rcWkgMzE")
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject(sc, carrier)
  assert_eq(
    carrier.get(@propagation.tracestate_header_name()),
    Some("congo=t61rcWkgMzE"),
  )
  assert_eq(
    carrier.get(@propagation.traceparent_header_name()),
    Some(@propagation.format_traceparent(sc)),
  )
}

///|
test "inject_skips_invalid_tracestate" {
  let sc = tracestate_test_context().with_tracestate("bad key=value")
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject(sc, carrier)
  assert_eq(carrier.get(@propagation.tracestate_header_name()), None)
  assert_true(carrier.get(@propagation.traceparent_header_name()) is Some(_))
}

///|
test "extract_attaches_valid_tracestate" {
  let sc = tracestate_test_context()
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    @propagation.traceparent_header_name(),
    @propagation.format_traceparent(sc),
  )
  carrier.set(@propagation.tracestate_header_name(), "a=1 , b=2")
  let extracted = @propagation.extract(carrier).unwrap()
  assert_eq(extracted.tracestate(), "a=1,b=2")
}

///|
test "extract_ignores_invalid_tracestate" {
  let sc = tracestate_test_context()
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    @propagation.traceparent_header_name(),
    @propagation.format_traceparent(sc),
  )
  carrier.set(@propagation.tracestate_header_name(), "not a valid state")
  let extracted = @propagation.extract(carrier).unwrap()
  assert_eq(extracted.tracestate(), "")
}

///|
test "extract_without_tracestate_leaves_it_empty" {
  let sc = tracestate_test_context()
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject(sc, carrier)
  let extracted = @propagation.extract(carrier).unwrap()
  assert_eq(extracted.tracestate(), "")
}

///|
test "parse_tracestate_rejects_headers_without_members" {
  // A header that holds no list-member at all carries no state; an empty
  // `tracestate` is not a valid header value.
  assert_eq(@propagation.parse_tracestate(","), None)
  assert_eq(@propagation.parse_tracestate(", ,"), None)
  assert_eq(@propagation.parse_tracestate("   "), None)
  assert_true(@propagation.Tracestate::parse(",") is None)
  assert_true(@propagation.Tracestate::parse(", ,") is None)
  assert_true(@propagation.Tracestate::parse("   ") is None)
}

///|
test "inject_skips_tracestate_without_members" {
  let sc = tracestate_test_context().with_tracestate(",")
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject(sc, carrier)
  assert_eq(carrier.get(@propagation.tracestate_header_name()), None)
  assert_true(carrier.get(@propagation.traceparent_header_name()) is Some(_))
}
