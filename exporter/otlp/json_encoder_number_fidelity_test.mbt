// Regression tests for numeric fields whose protobuf JSON representation is
// not the signed decimal form: `fixed64` timestamps are unsigned, and a
// negative-zero double keeps its sign bit.

///|
test "json_encoder_writes_timestamps_as_unsigned_fixed64_strings" {
  let base = json_test_span()
  let event = { ..base.events[0], time_unix_nano: -3L }
  let span : @sdk.SpanData = {
    ..base,
    start_time_unix_nano: -1L,
    end_time_unix_nano: -2L,
    events: [event],
  }
  let text = @utf8.decode_lossy(@otlp.encode_trace_request_json([span]))
  // `fixed64` is unsigned: -1 is encoded as 0xFFFFFFFFFFFFFFFF.
  assert_true(text.contains("\"startTimeUnixNano\":\"18446744073709551615\""))
  assert_true(text.contains("\"endTimeUnixNano\":\"18446744073709551614\""))
  assert_true(text.contains("\"timeUnixNano\":\"18446744073709551613\""))
  // Signed int attributes still use the signed decimal form.
  assert_true(text.contains("\"intValue\":\"42\""))
}

///|
test "json_encoder_preserves_negative_zero_doubles" {
  let base = json_test_span()
  let attributes = base.attributes.copy()
  attributes.set("negzero", @sdk.DoubleValue(-0.0))
  let span : @sdk.SpanData = { ..base, attributes, }
  let text = @utf8.decode_lossy(@otlp.encode_trace_request_json([span]))
  assert_true(text.contains("\"doubleValue\":-0"))
  // The document remains valid JSON.
  let _ = parse_json_text(text)
}
