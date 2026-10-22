// Repeated HTTP fields whose names differ only in casing must be treated as
// the same field (RFC 7230 section 3.2.2): `tracestate`/`baggage` values are
// combined, while two `traceparent` fields are ambiguous and restart the trace.

///|
let duplicate_traceparent_a : String = "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"

///|
let duplicate_traceparent_b : String = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"

///|
test "carrier_get_all_is_case_insensitive_and_ordered" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("tracestate", "a=1")
  carrier.set("TraceState", "b=2")
  assert_eq(carrier.get_all("TRACESTATE"), ["a=1", "b=2"])
  assert_eq(carrier.get_combined("TrAcEsTaTe"), Some("a=1, b=2"))
  assert_eq(carrier.get_all("missing"), [])
  assert_eq(carrier.get_combined("missing"), None)
}

///|
test "carrier_get_all_reads_an_external_getter_once" {
  let carrier = @propagation.TextMapCarrier::from_getter(fn(key) {
    if key == "traceparent" {
      Some(duplicate_traceparent_a)
    } else {
      None
    }
  })
  assert_eq(carrier.get_all("traceparent"), [duplicate_traceparent_a])
  assert_eq(carrier.get_combined("traceparent"), Some(duplicate_traceparent_a))
  assert_eq(carrier.get_all("tracestate"), [])
}

///|
test "carrier_write_through_setter_does_not_shadow_external_values" {
  let carrier = @propagation.TextMapCarrier::from_getter_setter(
    fn(_key) { Some(duplicate_traceparent_b) },
    fn(_key, _value) { () },
  )
  carrier.set("TraceParent", duplicate_traceparent_a)
  // A write-through carrier forwards the write and does not store it locally,
  // so reads still see the external value exactly once.
  assert_eq(carrier.get_all("traceparent"), [duplicate_traceparent_b])
}

///|
test "extract_rejects_duplicate_traceparent_with_different_casing" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("traceparent", duplicate_traceparent_a)
  carrier.set("TraceParent", duplicate_traceparent_b)
  assert_eq(carrier.length(), 2)
  assert_true(@propagation.extract(carrier) is None)
}

///|
test "extract_rejects_duplicate_traceparent_from_map" {
  let carrier = @propagation.TextMapCarrier::from_map(
    Map([
      ("traceparent", duplicate_traceparent_a),
      ("TraceParent", duplicate_traceparent_b),
    ]),
  )
  assert_true(@propagation.extract(carrier) is None)
}

///|
test "extract_combines_tracestate_fields_with_different_casing" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("traceparent", duplicate_traceparent_a)
  carrier.set("tracestate", "vendor=one")
  carrier.set("TraceState", "other=two")
  let context = @propagation.extract(carrier).unwrap()
  assert_eq(context.tracestate(), "vendor=one,other=two")
  assert_eq(
    @propagation.extract_tracestate(carrier),
    Some("vendor=one, other=two"),
  )
}

///|
test "extract_combines_baggage_fields_with_different_casing" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("baggage", "first=1")
  carrier.set("Baggage", "second=2")
  assert_eq(
    @propagation.extract_baggage(carrier),
    [("first", "1"), ("second", "2")],
  )
  let entries = @propagation.extract_baggage_entries(carrier)
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].key, "first")
  assert_eq(entries[1].key, "second")
}

///|
test "extract_single_traceparent_still_works" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("TraceParent", duplicate_traceparent_a)
  let context = @propagation.extract(carrier).unwrap()
  assert_eq(
    context.trace_id_hex(),
    "4bf92f359d1e75b7618a2d1f3c4e5a6b",
  )
}
