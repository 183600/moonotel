// Baggage parsing skips members with invalid values, and formatting rejects
// invalid keys.

///|
test "parse_baggage_skips_values_with_invalid_characters" {
  assert_eq(@propagation.parse_baggage("k=bad value"), [])
  assert_eq(@propagation.parse_baggage("good=1,bad=va\"lue,after=2"), [
    ("good", "1"),
    ("after", "2"),
  ])
}

///|
test "context_baggage_header_rejects_invalid_keys" {
  let context = @context.Context::root().with_value("bad key", "value")
  assert_true(@propagation.context_baggage_header(context) is None)
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_baggage(context, carrier)
  assert_eq(carrier.get(@propagation.baggage_header_name()), None)
}
