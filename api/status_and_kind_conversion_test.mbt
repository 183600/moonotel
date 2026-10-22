// Every `StatusCode` and `SpanKind` variant must have both its stable
// lower-case name and its OTLP numeric value, not just the variants that the
// HTTP instrumentation happens to use.

///|
test "status_code_conversions_cover_every_variant" {
  assert_eq(@api.StatusCode::Unset.to_string(), "unset")
  assert_eq(@api.StatusCode::Ok.to_string(), "ok")
  assert_eq(@api.StatusCode::Error.to_string(), "error")
  assert_eq(@api.StatusCode::Unset.otlp_value(), 0)
  assert_eq(@api.StatusCode::Ok.otlp_value(), 1)
  assert_eq(@api.StatusCode::Error.otlp_value(), 2)
}

///|
test "span_kind_conversions_cover_every_variant" {
  let kinds : Array[(@api.SpanKind, String, Int32)] = [
    (@api.SpanKind::Internal, "internal", 1),
    (@api.SpanKind::Server, "server", 2),
    (@api.SpanKind::Client, "client", 3),
    (@api.SpanKind::Producer, "producer", 4),
    (@api.SpanKind::Consumer, "consumer", 5),
  ]
  for entry in kinds {
    assert_eq(entry.0.to_string(), entry.1)
    assert_eq(entry.0.otlp_value(), entry.2)
  }
}
