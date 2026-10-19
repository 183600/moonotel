// Tests for the acceptance of original proto field names (snake_case) in
// OTLP/JSON export responses, as required by the protobuf JSON mapping.

///|
fn decode_proto_body(text : String) -> @sdk.ExportResult {
  @otlp.decode_export_response_json(@utf8.encode(text))
}

///|
fn proto_failure_message(result : @sdk.ExportResult) -> String {
  match result {
    @sdk.ExportFailure(message) => message
    @sdk.ExportSuccess => abort("expected an export failure")
  }
}

///|
test "json_decode_snake_case_partial_success" {
  let message = proto_failure_message(
    decode_proto_body("{\"partial_success\":{\"rejected_spans\":\"3\"}}"),
  )
  assert_true(message.contains("rejected 3 span(s)"))
}

///|
test "json_decode_snake_case_error_message" {
  let message = proto_failure_message(
    decode_proto_body(
      "{\"partial_success\":{\"rejected_spans\":1,\"error_message\":\"bad\"}}",
    ),
  )
  assert_true(message.contains("rejected 1 span(s)"))
  assert_true(message.contains("bad"))
}

///|
test "json_decode_snake_case_empty_partial_success_is_success" {
  assert_eq(decode_proto_body("{\"partial_success\":{}}"), @sdk.ExportSuccess)
  assert_eq(
    decode_proto_body("{\"partial_success\":{\"rejected_spans\":0}}"),
    @sdk.ExportSuccess,
  )
}

///|
test "json_decode_mixed_field_names" {
  let message = proto_failure_message(
    decode_proto_body(
      "{\"partialSuccess\":{\"rejected_spans\":\"2\",\"errorMessage\":\"mixed\"}}",
    ),
  )
  assert_true(message.contains("rejected 2 span(s)"))
  assert_true(message.contains("mixed"))
}

///|
test "json_decode_rejected_spans_exponent_form" {
  let message = proto_failure_message(
    decode_proto_body("{\"partialSuccess\":{\"rejectedSpans\":2e2}}"),
  )
  assert_true(message.contains("rejected 200 span(s)"))
}

///|
test "json_decode_rejected_spans_decimal_form" {
  let message = proto_failure_message(
    decode_proto_body("{\"partialSuccess\":{\"rejectedSpans\":3.0}}"),
  )
  assert_true(message.contains("rejected 3 span(s)"))
}

///|
test "json_decode_rejected_spans_fractional_is_malformed" {
  assert_eq(
    decode_proto_body("{\"partialSuccess\":{\"rejectedSpans\":1.5}}"),
    @sdk.ExportFailure("malformed OTLP response body"),
  )
}

///|
test "json_decode_snake_case_null_members_are_defaults" {
  assert_eq(
    decode_proto_body(
      "{\"partial_success\":{\"rejected_spans\":null,\"error_message\":null}}",
    ),
    @sdk.ExportSuccess,
  )
}
