// Tests for case-insensitive header lookup on TextMapCarrier.

///|
test "get is case-insensitive" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("TraceParent", "00-abc")
  assert_eq(carrier.get("traceparent"), Some("00-abc"))
  assert_eq(carrier.get("TRACEPARENT"), Some("00-abc"))
  assert_eq(carrier.get("TraceParent"), Some("00-abc"))
}

///|
test "exact match wins over case-insensitive match" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("traceparent", "exact")
  carrier.set("TraceParent", "other")
  assert_eq(carrier.get("traceparent"), Some("exact"))
}

///|
test "missing headers stay missing" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("tracestate", "vendor=value")
  assert_eq(carrier.get("traceparent"), None)
}

///|
test "remove deletes headers case-insensitively" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("TraceParent", "00-abc")
  carrier.set("tracestate", "vendor=value")
  carrier.remove("traceparent")
  assert_eq(carrier.get("traceparent"), None)
  assert_eq(carrier.length(), 1)
  carrier.remove("TRACESTATE")
  assert_eq(carrier.length(), 0)
}

///|
test "from_entries combines differently cased duplicate keys" {
  let carrier = @propagation.TextMapCarrier::from_entries([
    ("Tracestate", "foo=1"),
    ("tracestate", "bar=2"),
  ])
  assert_eq(carrier.length(), 1)
  assert_eq(carrier.get("tracestate"), Some("foo=1, bar=2"))
  assert_eq(carrier.get("TRACESTATE"), Some("foo=1, bar=2"))
}

///|
test "extract accepts differently cased traceparent headers" {
  let sc = @propagation.parse_traceparent(
    "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
  ).unwrap()
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("TraceParent", @propagation.format_traceparent(sc))
  let extracted = @propagation.extract(carrier).unwrap()
  assert_eq(extracted.trace_id_hex(), sc.trace_id_hex())
  assert_eq(extracted.span_id_hex(), sc.span_id_hex())
}
