// Blackbox tests for W3C Trace Context propagation.

///|
fn make_context() -> @api.SpanContext {
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
test "format_traceparent_round_trip" {
  let sc = make_context()
  let value = @propagation.format_traceparent(sc)
  assert_eq(value, "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01")
  let parsed = @propagation.parse_traceparent(value)
  assert_true(parsed is Some(_))
  let round = parsed.unwrap()
  assert_true(round.is_valid())
  assert_eq(round.trace_id_hex(), sc.trace_id_hex())
  assert_eq(round.span_id_hex(), sc.span_id_hex())
  assert_true(round.is_sampled())
}

///|
test "format_invalid_context_is_empty" {
  let sc = @api.invalid_span_context()
  assert_eq(@propagation.format_traceparent(sc), "")
}

///|
test "parse_unsampled_flags" {
  let value = "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-00"
  let parsed = @propagation.parse_traceparent(value)
  assert_true(parsed is Some(_))
  assert_false(parsed.unwrap().is_sampled())
}

///|
test "parse_masks_unknown_flag_bits" {
  let value = "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-ff"
  let parsed = @propagation.parse_traceparent(value)
  assert_true(parsed is Some(_))
  // Only the sampled (`01`) and random (`02`) bits are kept; every other
  // bit is reserved and must be set to zero.
  assert_eq(parsed.unwrap().trace_flags(), 3)
  assert_true(parsed.unwrap().is_sampled())
}

///|
test "parse_keeps_random_flag_and_format_preserves_it" {
  // The random-trace-id flag (`02`) must survive parse and format so that
  // an outgoing header keeps it (W3C Trace Context Level 2).
  let value = "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-02"
  let parsed = @propagation.parse_traceparent(value).unwrap()
  assert_eq(parsed.trace_flags(), 2)
  assert_false(parsed.is_sampled())
  assert_eq(
    @propagation.format_traceparent(parsed),
    "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-02",
  )
}

///|
test "parse_version_00_rejects_uppercase_hex" {
  // The version 00 ABNF spells trace-id, parent-id and trace-flags
  // `HEXDIGLC`; uppercase hex characters invalidate the header.
  let value = "00-4BF92F359D1E75B7618A2D1F3C4E5A6B-00F067AA0BA902B7-01"
  assert_true(@propagation.parse_traceparent(value) is None)
  assert_true(
    @propagation.parse_traceparent(
      "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00F067AA0BA902B7-01",
    )
    is None,
  )
  assert_true(
    @propagation.parse_traceparent(
      "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-0A",
    )
    is None,
  )
}

///|
test "parse_higher_version_accepts_uppercase_hex" {
  // For a higher version the fields only have to be hex, in either case.
  let value = "01-4BF92F359D1E75B7618A2D1F3C4E5A6B-00F067AA0BA902B7-01"
  let parsed = @propagation.parse_traceparent(value)
  assert_true(parsed is Some(_))
  assert_eq(parsed.unwrap().trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
  assert_eq(parsed.unwrap().span_id_hex(), "00f067aa0ba902b7")
  assert_true(parsed.unwrap().is_sampled())
}

///|
test "parse_rejects_all_zero_trace_id" {
  let value = "00-00000000000000000000000000000000-00f067aa0ba902b7-01"
  assert_true(@propagation.parse_traceparent(value) is None)
}

///|
test "parse_rejects_all_zero_span_id" {
  let value = "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-0000000000000000-01"
  assert_true(@propagation.parse_traceparent(value) is None)
}

///|
test "parse_rejects_version_ff" {
  let value = "ff-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"
  assert_true(@propagation.parse_traceparent(value) is None)
}

///|
test "parse_rejects_too_few_fields" {
  assert_true(
    @propagation.parse_traceparent("00-4bf92f359d1e75b7618a2d1f3c4e5a6b")
    is None,
  )
  assert_true(@propagation.parse_traceparent("") is None)
  assert_true(@propagation.parse_traceparent("00") is None)
}

///|
test "parse_rejects_wrong_field_lengths" {
  assert_true(
    @propagation.parse_traceparent("00-4bf92f35-00f067aa0ba902b7-01") is None,
  )
  assert_true(
    @propagation.parse_traceparent(
      "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-1",
    )
    is None,
  )
  assert_true(
    @propagation.parse_traceparent(
      "00-4bf92f359d1e75b7618a2d1f3c4e5a6b0-00f067aa0ba902b7-01",
    )
    is None,
  )
}

///|
test "parse_rejects_invalid_hex" {
  let value = "00-4bf92f359d1e75b7618a2d1f3c4e5a6g-00f067aa0ba902b7-01"
  assert_true(@propagation.parse_traceparent(value) is None)
}

///|
test "parse_version_00_rejects_extra_fields" {
  let value = "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01-extra"
  assert_true(@propagation.parse_traceparent(value) is None)
}

///|
test "parse_version_01_ignores_extra_fields" {
  let value = "01-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01-extra"
  let parsed = @propagation.parse_traceparent(value)
  assert_true(parsed is Some(_))
  assert_true(parsed.unwrap().is_valid())
}

///|
test "carrier_basic_operations" {
  let carrier = @propagation.TextMapCarrier::new()
  assert_eq(carrier.length(), 0)
  carrier.set("k", "v")
  assert_eq(carrier.length(), 1)
  assert_eq(carrier.get("k"), Some("v"))
  assert_eq(carrier.get("missing"), None)
}

///|
test "carrier_from_entries" {
  let carrier = @propagation.TextMapCarrier::from_entries([
    ("a", "1"),
    ("b", "2"),
  ])
  assert_eq(carrier.length(), 2)
  assert_eq(carrier.get("a"), Some("1"))
  assert_eq(carrier.get("b"), Some("2"))
}

///|
test "carrier_from_entries_combines_duplicate_keys" {
  // RFC 7230 section 3.2.2: repeated header fields are combined with ", ".
  let carrier = @propagation.TextMapCarrier::from_entries([
    ("tracestate", "foo=1"),
    ("tracestate", "bar=2"),
  ])
  assert_eq(carrier.length(), 1)
  assert_eq(carrier.get("tracestate"), Some("foo=1, bar=2"))
  assert_eq(
    @propagation.extract_tracestate(carrier),
    Some("foo=1, bar=2"),
  )
  assert_eq(
    @propagation.parse_tracestate(carrier.get("tracestate").unwrap()),
    Some("foo=1,bar=2"),
  )
  // A duplicated traceparent no longer parses after combining, so extraction
  // restarts with a new trace.
  let dup = @propagation.TextMapCarrier::from_entries([
    ("traceparent", "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"),
    ("traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"),
  ])
  assert_true(
    @propagation.parse_traceparent(dup.get("traceparent").unwrap()) is None,
  )
}

///|
test "inject_and_extract_round_trip" {
  let sc = make_context()
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject(sc, carrier)
  assert_eq(
    carrier.get(@propagation.traceparent_header_name()),
    Some(@propagation.format_traceparent(sc)),
  )
  let extracted = @propagation.extract(carrier)
  assert_true(extracted is Some(_))
  assert_eq(extracted.unwrap().span_id_hex(), sc.span_id_hex())
}

///|
test "inject_invalid_context_writes_nothing" {
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject(@api.invalid_span_context(), carrier)
  assert_eq(carrier.length(), 0)
}

///|
test "extract_missing_header" {
  let carrier = @propagation.TextMapCarrier::new()
  assert_true(@propagation.extract(carrier) is None)
  assert_true(@propagation.extract_tracestate(carrier) is None)
}

///|
test "tracestate_passthrough" {
  let sc = make_context()
  let carrier = @propagation.TextMapCarrier::new()
  let state = "congo=t61rcWkgMzE,rojo=00f067aa0ba902b7"
  @propagation.inject_with_tracestate(sc, Some(state), carrier)
  assert_eq(carrier.get(@propagation.tracestate_header_name()), Some(state))
  assert_eq(@propagation.extract_tracestate(carrier), Some(state))
}

///|
test "tracestate_empty_is_not_injected" {
  let sc = make_context()
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject_with_tracestate(sc, Some(""), carrier)
  assert_eq(@propagation.extract_tracestate(carrier), None)
}

///|
test "format_traceparent_never_reads_past_a_shortened_aliased_id" {
  // `span_context` aliases its input arrays, so a caller can shorten an ID
  // after construction while the snapshotted validity flag still says true.
  // Formatting must not read 16/8 elements from the now-shorter arrays.
  let shortened_trace = make_context()
  shortened_trace.trace_id_view().clear()
  assert_eq(@propagation.format_traceparent(shortened_trace), "")

  let shortened_span = make_context()
  shortened_span.span_id_view().clear()
  assert_eq(@propagation.format_traceparent(shortened_span), "")

  let both = make_context()
  both.trace_id_view().clear()
  both.span_id_view().clear()
  assert_eq(@propagation.format_traceparent(both), "")
}

///|
test "inject_ignores_a_context_with_shortened_live_ids" {
  let sc = make_context()
  sc.trace_id_view().clear()
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.inject(sc, carrier)
  assert_eq(carrier.length(), 0)
  @propagation.inject_with_tracestate(sc, Some("a=1"), carrier)
  assert_eq(carrier.length(), 0)
}

///|
test "format_traceparent_rejects_live_ids_that_serialize_to_all_zero" {
  let sc = make_context()
  let trace = sc.trace_id_view()
  for i = 0; i < trace.length(); i = i + 1 {
    trace[i] = 0
  }
  assert_eq(@propagation.format_traceparent(sc), "")

  let span_zero = make_context()
  let span = span_zero.span_id_view()
  for i = 0; i < span.length(); i = i + 1 {
    span[i] = 0
  }
  assert_eq(@propagation.format_traceparent(span_zero), "")
}

///|
test "format_traceparent_uses_serialized_bytes_for_live_id_validity" {
  // Values outside 0..255 serialize with a zero high nibble, so 0x100 is an
  // all-zero wire byte rather than a nonzero ID element.
  let sc = make_context()
  let trace = sc.trace_id_view()
  for i = 0; i < trace.length(); i = i + 1 {
    trace[i] = 0x100
  }
  assert_eq(@propagation.format_traceparent(sc), "")
}

///|
test "inject_removes_headers_for_live_ids_that_serialize_to_all_zero" {
  let sc = make_context()
  let trace = sc.trace_id_view()
  for i = 0; i < trace.length(); i = i + 1 {
    trace[i] = 0
  }
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(@propagation.traceparent_header_name(), "stale")
  carrier.set(@propagation.tracestate_header_name(), "stale=value")
  @propagation.inject(sc, carrier)
  assert_eq(carrier.length(), 0)

  let explicit = @propagation.TextMapCarrier::new()
  explicit.set(@propagation.traceparent_header_name(), "stale")
  explicit.set(@propagation.tracestate_header_name(), "stale=value")
  @propagation.inject_with_tracestate(sc, Some("vendor=value"), explicit)
  assert_eq(explicit.length(), 0)
}
