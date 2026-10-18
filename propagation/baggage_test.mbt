// Blackbox tests for W3C Baggage propagation.

///|
test "percent_encode_escapes_reserved_characters" {
  assert_eq(@propagation.percent_encode("a b,c;d\\e"), "a%20b%2Cc%3Bd%5Ce")
}

///|
test "percent_encode_escapes_percent_and_quote" {
  assert_eq(@propagation.percent_encode("100%"), "100%25")
  assert_eq(@propagation.percent_encode("a\"b"), "a%22b")
}

///|
test "percent_decode_round_trips_percent" {
  assert_eq(@propagation.percent_decode("100%25"), Some("100%"))
  assert_eq(@propagation.percent_decode("a%22b"), Some("a\"b"))
}

///|
test "baggage_round_trips_percent_in_value" {
  let header = @propagation.format_baggage([("a", "100%")])
  assert_eq(header, "a=100%25")
  assert_eq(@propagation.parse_baggage(header), [("a", "100%")])
}

///|
test "percent_encode_keeps_allowed_characters" {
  assert_eq(@propagation.percent_encode("abc-._~123"), "abc-._~123")
}

///|
test "percent_decode_round_trips" {
  let original = "hello world, 世界!"
  assert_eq(
    @propagation.percent_decode(@propagation.percent_encode(original)),
    Some(original),
  )
}

///|
test "percent_decode_accepts_lowercase_hex" {
  assert_eq(@propagation.percent_decode("a%2cb"), Some("a,b"))
}

///|
test "percent_decode_rejects_bad_sequences" {
  assert_eq(@propagation.percent_decode("%"), None)
  assert_eq(@propagation.percent_decode("%2"), None)
  assert_eq(@propagation.percent_decode("%zz"), None)
}

///|
test "parse_baggage_basic" {
  let entries = @propagation.parse_baggage(
    "userId=alice,serverNode=DF%2028,isProduction=false",
  )
  assert_eq(entries.length(), 3)
  assert_eq(entries[0], ("userId", "alice"))
  assert_eq(entries[1], ("serverNode", "DF 28"))
  assert_eq(entries[2], ("isProduction", "false"))
}

///|
test "parse_baggage_drops_properties" {
  let entries = @propagation.parse_baggage("a=1;prop=2;flag")
  assert_eq(entries.length(), 1)
  assert_eq(entries[0], ("a", "1"))
}

///|
test "parse_baggage_skips_invalid_members" {
  let entries = @propagation.parse_baggage("bad key=3,a=1,b=2")
  assert_eq(entries.length(), 2)
  assert_eq(entries[0], ("a", "1"))
  assert_eq(entries[1], ("b", "2"))
}

///|
test "parse_baggage_empty_is_empty" {
  assert_eq(@propagation.parse_baggage("").length(), 0)
}

///|
test "format_baggage_encodes_values" {
  assert_eq(@propagation.format_baggage([("k", "a b")]), "k=a%20b")
  assert_eq(@propagation.format_baggage([("a", "1"), ("b", "2")]), "a=1,b=2")
}

///|
test "format_baggage_skips_invalid_keys" {
  assert_eq(@propagation.format_baggage([("bad key", "v")]), "")
}

///|
test "inject_and_extract_baggage_round_trip" {
  let context = @context.Context::root()
    .with_value("user.id", "42")
    .with_value("note", "a,b")
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_baggage(context, carrier)
  assert_eq(
    carrier.get(@propagation.baggage_header_name()),
    Some("note=a%2Cb,user.id=42"),
  )
  let entries = @propagation.extract_baggage(carrier)
  assert_eq(entries.length(), 2)
  let restored = @propagation.extract_baggage_context(carrier)
  assert_eq(restored.value("note"), Some("a,b"))
  assert_eq(restored.value("user.id"), Some("42"))
}

///|
test "inject_baggage_is_noop_without_baggage" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_baggage(@context.Context::root(), carrier)
  assert_eq(carrier.length(), 0)
}

///|
test "extract_baggage_missing_header" {
  let carrier = @propagation.TextMapCarrier::new()
  assert_eq(@propagation.extract_baggage(carrier).length(), 0)
  assert_eq(@propagation.extract_baggage_context(carrier).baggage().length(), 0)
}

///|
test "inject_baggage_omits_removed_keys" {
  let context = @context.Context::root()
    .with_value("user.id", "42")
    .with_value("secret", "hidden")
    .without_value("secret")
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_baggage(context, carrier)
  assert_eq(carrier.get(@propagation.baggage_header_name()), Some("user.id=42"))
}
