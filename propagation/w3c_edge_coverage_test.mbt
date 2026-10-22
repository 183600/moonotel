// Additional boundary coverage for traceparent flags/casing and for the
// write-through `TextMapCarrier` constructor.

///|
fn edge_coverage_context() -> @api.SpanContext {
  @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    1,
  )
}

///|
test "parse_traceparent_rejects_non_hex_flags" {
  for flags in [".0", "0.", "g0", "0g", "zz"] {
    let value = "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-" + flags
    assert_true(@propagation.parse_traceparent(value) is None)
  }
}

///|
test "parse_traceparent_version_00_requires_lowercase_hex" {
  let value = "00-4BF92F359D1E75B7618A2D1F3C4E5A6B-00F067AA0BA902B7-01"
  assert_true(@propagation.parse_traceparent(value) is None)
}

///|
test "parse_traceparent_future_version_accepts_uppercase_hex" {
  // The specification only spells the version 00 fields as HEXDIGLC. Future
  // versions accept either case, but the decoded IDs are still normalized.
  let value = "01-4BF92F359D1E75B7618A2D1F3C4E5A6B-00F067AA0BA902B7-01"
  let parsed = @propagation.parse_traceparent(value)
  assert_true(parsed is Some(_))
  let sc = parsed.unwrap()
  assert_eq(sc.trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
  assert_eq(sc.span_id_hex(), "00f067aa0ba902b7")
}

///|
test "parse_traceparent_keeps_only_the_known_trace_flag_bits" {
  let value = "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-ff"
  let sc = @propagation.parse_traceparent(value).unwrap()
  assert_eq(sc.trace_flags(), 3)
  assert_true(sc.is_sampled())
}

///|
test "format_traceparent_of_an_invalid_context_is_empty" {
  assert_eq(@propagation.format_traceparent(@api.invalid_span_context()), "")
}

///|
test "write_through_carrier_does_not_keep_local_entries" {
  let store : Map[String, String] = Map([])
  let carrier = @propagation.TextMapCarrier::from_setter(fn(key, value) {
    store.set(key, value)
  })
  carrier.set("traceparent", "00-value")
  assert_eq(store.get("traceparent"), Some("00-value"))
  assert_eq(carrier.length(), 0)
  // Reads only see local entries for a setter-only carrier.
  assert_eq(carrier.get("traceparent"), None)
}

///|
test "extract_without_traceparent_returns_none" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(@propagation.baggage_header_name(), "user=alice")
  assert_true(@propagation.extract(carrier) is None)
}

///|
test "tracestate_empty_header_and_removal" {
  assert_eq(@propagation.Tracestate::empty().to_header(), "")
  let state = @propagation.Tracestate::parse("a=1,b=2").unwrap()
  assert_eq(state.remove("missing").to_header(), "a=1,b=2")
  assert_eq(state.remove("a").to_header(), "b=2")
  let context = edge_coverage_context().with_tracestate("")
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject(context, carrier)
  assert_eq(carrier.get(@propagation.tracestate_header_name()), None)
}
