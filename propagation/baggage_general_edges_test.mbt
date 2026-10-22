// Edge coverage for the general (lenient) baggage parser, surrogate-safe
// percent encoding and carrier/propagator operations that do not write a trace
// context.

///|
test "general_baggage_parser_trims_ows_after_equals" {
  assert_eq(@propagation.parse_baggage("a= 1 , b = 2"), [
    ("a", "1"),
    ("b", "2"),
  ])
  let entries = @propagation.parse_baggage_entries("a= v ; p = q ")
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].value, "v")
  assert_eq(entries[0].properties, [("p", "q")])
}

///|
test "general_baggage_parser_stops_at_the_member_limit" {
  let sb = StringBuilder()
  let mut i = 0
  while i < 80 {
    if i > 0 {
      // The whitespace forces the general parser instead of the fast path.
      sb.write_string(", ")
    }
    sb.write_string("k" + i.to_string())
    sb.write_char('=')
    sb.write_string("v")
    i = i + 1
  }
  let header = sb.to_string()
  let entries = @propagation.parse_baggage_entries(header)
  assert_eq(entries.length(), @propagation.BAGGAGE_MAX_MEMBERS)
  assert_eq(entries[0].key, "k0")
  assert_eq(entries[63].key, "k63")
  let pairs = @propagation.parse_baggage(header)
  assert_eq(pairs.length(), @propagation.BAGGAGE_MAX_MEMBERS)
  assert_eq(pairs[63], ("k63", "v"))
}

///|
test "percent_encoding_keeps_a_valid_pair_after_an_unpaired_surrogate" {
  let lone_high = String::from_array([(0xD800).unsafe_to_char()])
  let text = lone_high + "😀"
  assert_eq(@propagation.percent_encoded_length(text), 21)
  assert_eq(@propagation.percent_encode(text), "%EF%BF%BD%F0%9F%98%80")
}

///|
test "trace_context_propagator_without_a_span_writes_nothing" {
  let context = @context.Context::root().with_value("k", "v")
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("x-keep", "1")
  let propagator = @propagation.TraceContextPropagator::new()
  propagator.inject(context, carrier)
  assert_eq(carrier.get(@propagation.traceparent_header_name()), None)
  assert_eq(carrier.get("x-keep"), Some("1"))
  let extracted = propagator.extract(carrier)
  assert_true(extracted.span_context() is None)
}

///|
test "carrier_remove_deletes_every_case_variant" {
  let carrier = @propagation.TextMapCarrier::from_map(
    Map([("X-Token", "one"), ("x-token", "two"), ("other", "three")]),
  )
  carrier.remove("x-token")
  assert_eq(carrier.length(), 1)
  assert_eq(carrier.get("x-token"), None)
  assert_eq(carrier.get("X-Token"), None)
  assert_eq(carrier.get("other"), Some("three"))
}
