// Boundary coverage for the lenient (general) baggage parser/formatter and
// for future-version `traceparent` values that contain non-ASCII text.
//
// These cases exercise paths that the fast parsers deliberately skip: OWS
// around properties, the normalized byte budget when properties are present,
// and hex validation of a future-version trace ID.

///|
fn boundary_baggage_value(length : Int32) -> String {
  let sb = StringBuilder(size_hint=length)
  let mut i = 0
  while i < length {
    sb.write_char('v')
    i = i + 1
  }
  sb.to_string()
}

///|
test "general_baggage_parser_trims_property_ows_before_a_separator" {
  // The space before `;` forces the general parser and must be removed from
  // the property value; the property key is trimmed around its own `=`.
  let entries = @propagation.parse_baggage_entries("a=1;p = q ;r=2")
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].properties, [("p", "q"), ("r", "2")])
}

///|
test "general_baggage_parser_drops_members_beyond_the_byte_budget" {
  // A leading space (and the spaces around the members) forces the general
  // parser. As with the fast parser, members beyond the 8192-byte budget are
  // dropped whole.
  let value = boundary_baggage_value(300)
  let sb = StringBuilder()
  let mut i = 0
  while i < 40 {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_char(' ')
    sb.write_string("k" + i.to_string())
    sb.write_char('=')
    sb.write_string(value)
    i = i + 1
  }
  let entries = @propagation.parse_baggage_entries(sb.to_string())
  // k0 occupies 303 bytes, k1..k9 304 each and k10.. 305 each, so exactly 26
  // members fit in the 8192-byte budget.
  assert_eq(entries.length(), 26)
  assert_eq(entries[0].key, "k0")
  assert_eq(entries[25].key, "k25")
  let pairs = @propagation.parse_baggage(sb.to_string())
  assert_eq(pairs.length(), 26)
  assert_eq(pairs[25], ("k25", value))
}

///|
test "general_baggage_formatter_respects_the_byte_budget_with_properties" {
  // Properties force the general formatter path. It must still stop once the
  // next member would exceed 8192 bytes instead of emitting an oversized
  // header.
  let value = boundary_baggage_value(300)
  let entries : Array[@propagation.BaggageEntry] = []
  let mut i = 0
  while i < 40 {
    entries.push(
      @propagation.BaggageEntry::new(
        "k" + i.to_string(),
        value,
        properties=[("p", "v")],
      ),
    )
    i = i + 1
  }
  let header = @propagation.format_baggage_entries(entries)
  assert_true(header.length() <= @propagation.BAGGAGE_MAX_BYTES)
  assert_true(header.length() > 0)
  let reparsed = @propagation.parse_baggage_entries(header)
  assert_true(reparsed.length() < entries.length())
  assert_eq(reparsed[0].key, "k0")
  assert_eq(reparsed[0].properties, [("p", "v")])
}

///|
test "future_traceparent_rejects_a_non_ascii_id" {
  // Version 01 accepts upper- and lower-case hex, but never non-ASCII text.
  let sb = StringBuilder()
  sb.write_string("01-")
  let mut i = 0
  while i < 32 {
    sb.write_string("é")
    i = i + 1
  }
  sb.write_string("-00f067aa0ba902b7-01")
  assert_true(@propagation.parse_traceparent(sb.to_string()) is None)
}

///|
test "trace_context_propagator_inject_clears_stale_headers_for_an_invalid_span" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    "traceparent",
    "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01",
  )
  carrier.set("tracestate", "vendor=value")
  let context = @context.Context::root().with_span(
    @api.invalid_span_context(),
  )
  @propagation.TraceContextPropagator::new().inject(context, carrier)
  assert_true(carrier.get("traceparent") is None)
  assert_true(carrier.get("tracestate") is None)
}

///|
test "carrier_get_falls_back_to_the_external_getter_after_a_local_miss" {
  let carrier = @propagation.TextMapCarrier::from_getter(fn(key) {
    if key == "x-external" {
      Some("value")
    } else {
      None
    }
  })
  carrier.set("x-local", "local")
  assert_eq(carrier.get("x-local"), Some("local"))
  assert_eq(carrier.get("x-external"), Some("value"))
  assert_eq(carrier.get("x-missing"), None)
}
