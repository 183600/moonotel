// Regression tests: `rejected_spans`/`rejectedSpans` is a span count, so a
// negative value is malformed rather than a partial success.

///|
test "protobuf_negative_rejected_spans_is_malformed" {
  // ExportTraceServiceResponse { partial_success { rejected_spans = -1 } }
  let body : Bytes = b"\x0a\x0b\x08\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01"
  assert_eq(
    @otlp.decode_export_response(body),
    @sdk.ExportFailure("malformed OTLP response body"),
  )
}

///|
test "json_negative_rejected_spans_is_malformed" {
  for body in [
    "{\"partialSuccess\":{\"rejectedSpans\":\"-1\"}}",
    "{\"partialSuccess\":{\"rejectedSpans\":-1}}",
    "{\"partialSuccess\":{\"rejectedSpans\":-1.0}}",
    "{\"partialSuccess\":{\"rejectedSpans\":-1e0}}",
    "{\"partialSuccess\":{\"rejectedSpans\":\"-9223372036854775808\"}}",
  ] {
    assert_eq(
      json_failure_message(decode_json_body(body)),
      "malformed OTLP response body",
    )
  }
}
