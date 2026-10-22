// Edge cases of traceparent/tracestate parsing and injection.

///|
fn w3c_edge_context() -> @api.SpanContext {
  @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    1,
  )
}

///|
test "parse_rejects_non_hex_version" {
  let value = "zz-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"
  assert_true(@propagation.parse_traceparent(value) is None)
}

///|
test "parse_traceparent_trims_ows" {
  let inner = "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"
  for padded in [
    " " + inner,
    "\t" + inner,
    inner + " ",
    inner + "\t",
    "\t " + inner + " \t",
  ] {
    let parsed = @propagation.parse_traceparent(padded)
    assert_true(parsed is Some(_))
    let sc = parsed.unwrap()
    assert_eq(sc.trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
    assert_eq(sc.span_id_hex(), "00f067aa0ba902b7")
    assert_true(sc.is_sampled())
  }
  // OWS only trims at the edges; internal whitespace stays invalid.
  assert_true(
    @propagation.parse_traceparent("00 -4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01")
    is None,
  )
}

///|
test "parse_accepts_empty_future_version_extension" {
  // W3C Trace Context only requires the flags to be followed by the end of
  // the value or a dash; a future version may append an empty extension.
  let value = "01-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01-"
  let parsed = @propagation.parse_traceparent(value)
  assert_true(parsed is Some(_))
  let sc = parsed.unwrap()
  assert_eq(sc.trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
  assert_eq(sc.span_id_hex(), "00f067aa0ba902b7")
  assert_true(sc.is_sampled())
}

///|
test "parse_rejects_future_version_extension_without_delimiter" {
  // A character directly after the flags is neither the end of the value nor
  // a dash, so the header is malformed even for a future version.
  let value = "01-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01x"
  assert_true(@propagation.parse_traceparent(value) is None)
}

///|
test "parse_rejects_invalid_span_id_hex" {
  let value = "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-zzzzzzzzzzzzzzzz-01"
  assert_true(@propagation.parse_traceparent(value) is None)
}

///|
test "inject_without_tracestate_writes_no_tracestate_header" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_with_tracestate(w3c_edge_context(), None, carrier)
  assert_true(carrier.get(@propagation.traceparent_header_name()) is Some(_))
  assert_eq(@propagation.extract_tracestate(carrier), None)
}

///|
test "inject_with_tracestate_skips_invalid_span_context" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_with_tracestate(
    @api.invalid_span_context(), Some("a=1"), carrier,
  )
  assert_eq(carrier.length(), 0)
}

///|
test "parse_tracestate_keeps_first_duplicate_third_member" {
  assert_eq(
    @propagation.parse_tracestate("a=1,b=2,c=3,b=4"),
    Some("a=1,b=2,c=3"),
  )
}

///|
test "parse_rejects_non_ascii_version" {
  let value = "é0-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"
  assert_true(@propagation.parse_traceparent(value) is None)
}

///|
test "format_traceparent_masks_out_of_range_bytes" {
  let sc = @api.span_context(Array::make(16, 999), Array::make(8, -1), 1)
  let sb = StringBuilder()
  sb.write_string("00-")
  for i = 0; i < 16; i = i + 1 {
    sb.write_string("07")
  }
  sb.write_char('-')
  for i = 0; i < 8; i = i + 1 {
    sb.write_string("0f")
  }
  sb.write_string("-01")
  assert_eq(@propagation.format_traceparent(sc), sb.to_string())
}

///|
test "parse_tracestate_rejects_overlong_member_value" {
  let sb = StringBuilder()
  sb.write_string("a=")
  for i = 0; i < 257; i = i + 1 {
    sb.write_char('x')
  }
  assert_true(@propagation.parse_tracestate(sb.to_string()) is None)
  assert_true(@propagation.Tracestate::parse(sb.to_string()) is None)
}

///|
test "parse_tracestate_accepts_max_length_member_value" {
  let sb = StringBuilder()
  sb.write_string("a=")
  for i = 0; i < 256; i = i + 1 {
    sb.write_char('x')
  }
  let value = sb.to_string()
  assert_eq(@propagation.parse_tracestate(value), Some(value))
  assert_true(@propagation.Tracestate::parse(value) is Some(_))
}

///|
test "inject_with_tracestate_normalizes_a_valid_override" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_with_tracestate(
    w3c_edge_context(), Some(" a=1 , b=2 "), carrier,
  )
  assert_eq(@propagation.extract_tracestate(carrier), Some("a=1,b=2"))
}

///|
test "inject_with_tracestate_drops_an_invalid_override" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_with_tracestate(
    w3c_edge_context(), Some("not a valid state"), carrier,
  )
  assert_true(carrier.get(@propagation.traceparent_header_name()) is Some(_))
  assert_eq(@propagation.extract_tracestate(carrier), None)
}

///|
test "inject_with_tracestate_drops_a_header_without_members" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_with_tracestate(w3c_edge_context(), Some(" , "), carrier)
  assert_eq(@propagation.extract_tracestate(carrier), None)
}
