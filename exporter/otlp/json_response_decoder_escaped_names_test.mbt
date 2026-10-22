// JSON object member names may use `\uXXXX` escapes. The response decoder
// compares the decoded names, so a partial-success field written with escapes
// must be handled exactly like its literal spelling. Unknown fields may hold
// any JSON value, including positive, negative and exponent-form numbers.

///|
fn decode_escaped_json_body(text : String) -> @sdk.ExportResult {
  @otlp.decode_export_response_json(@utf8.encode(text))
}

///|
fn escaped_json_failure_message(result : @sdk.ExportResult) -> String {
  match result {
    @sdk.ExportFailure(message) => message
    @sdk.ExportSuccess => abort("expected an export failure")
  }
}

///|
test "json_decode_matches_escaped_partial_success_field_names" {
  let message = escaped_json_failure_message(
    decode_escaped_json_body(
      "{\"partial\\u0053uccess\":{\"rejectedSpans\":\"2\"}}",
    ),
  )
  assert_true(message.contains("rejected 2 span(s)"))
  let message = escaped_json_failure_message(
    decode_escaped_json_body(
      "{\"partialSuccess\":{\"\\u0072ejectedSpans\":3}}",
    ),
  )
  assert_true(message.contains("rejected 3 span(s)"))
  let message = escaped_json_failure_message(
    decode_escaped_json_body(
      "{\"partialSuccess\":{\"error\\u004dessage\":\"bad data\"}}",
    ),
  )
  assert_true(message.contains("bad data"))
}

///|
test "json_decode_skips_unknown_numeric_field_values" {
  let message = escaped_json_failure_message(
    decode_escaped_json_body(
      "{\"positive\":12345,\"negative\":-12345,\"decimal\":1.5e10,\"zero\":0,\"partialSuccess\":{\"rejectedSpans\":1}}",
    ),
  )
  assert_true(message.contains("rejected 1 span(s)"))
  assert_eq(decode_escaped_json_body("{\"unknown\":12345}"), @sdk.ExportSuccess)
  assert_eq(decode_escaped_json_body("{\"unknown\":-0.0}"), @sdk.ExportSuccess)
}

///|
test "json_decode_still_rejects_malformed_escaped_names" {
  for body in [
    "{\"partial\\u00\":{\"rejectedSpans\":1}}",
    "{\"partial\\uZZZZuccess\":{\"rejectedSpans\":1}}",
    "{\"partialSuccess\":{\"\\u0072ejectedSpans\":1}",
  ] {
    assert_false(decode_escaped_json_body(body).is_success())
  }
}
