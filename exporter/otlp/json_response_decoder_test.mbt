// Tests for the OTLP/JSON `ExportTraceServiceResponse` decoder.

///|
fn decode_json_body(text : String) -> @sdk.ExportResult {
  @otlp.decode_export_response_json(@utf8.encode(text))
}

///|
fn json_failure_message(result : @sdk.ExportResult) -> String {
  match result {
    @sdk.ExportFailure(message) => message
    @sdk.ExportSuccess => abort("expected an export failure")
  }
}

///|
test "json_decode_empty_body_is_success" {
  assert_eq(@otlp.decode_export_response_json(b""), @sdk.ExportSuccess)
}

///|
test "json_decode_whitespace_only_is_success" {
  assert_eq(decode_json_body(" \n\t "), @sdk.ExportSuccess)
}

///|
test "json_decode_empty_object_is_success" {
  assert_eq(decode_json_body("{}"), @sdk.ExportSuccess)
}

///|
test "json_decode_empty_partial_success_is_success" {
  assert_eq(decode_json_body("{\"partialSuccess\":{}}"), @sdk.ExportSuccess)
  assert_eq(
    decode_json_body("{\"partialSuccess\":{\"rejectedSpans\":\"0\"}}"),
    @sdk.ExportSuccess,
  )
  assert_eq(
    decode_json_body("{\"partialSuccess\":{\"rejectedSpans\":0}}"),
    @sdk.ExportSuccess,
  )
}

///|
test "json_decode_partial_success_rejected_spans_string" {
  let message = json_failure_message(
    decode_json_body("{\"partialSuccess\":{\"rejectedSpans\":\"3\"}}"),
  )
  assert_true(message.contains("rejected 3 span(s)"))
}

///|
test "json_decode_partial_success_rejected_spans_number" {
  let message = json_failure_message(
    decode_json_body("{\"partialSuccess\":{\"rejectedSpans\":2}}"),
  )
  assert_true(message.contains("rejected 2 span(s)"))
}

///|
test "json_decode_partial_success_error_message" {
  let message = json_failure_message(
    decode_json_body("{\"partialSuccess\":{\"errorMessage\":\"boom\"}}"),
  )
  assert_true(message.contains("boom"))
}

///|
test "json_decode_partial_success_rejected_and_message" {
  let message = json_failure_message(
    decode_json_body(
      "{\"partialSuccess\":{\"rejectedSpans\":\"5\",\"errorMessage\":\"bad data\"}}",
    ),
  )
  assert_true(message.contains("rejected 5 span(s)"))
  assert_true(message.contains("bad data"))
}

///|
test "json_decode_partial_success_escaped_message" {
  let message = json_failure_message(
    decode_json_body(
      "{\"partialSuccess\":{\"errorMessage\":\"say \\\"hi\\\"\\nnow\"}}",
    ),
  )
  assert_true(message.contains("say \"hi\"\nnow"))
}

///|
test "json_decode_skips_unknown_fields" {
  let message = json_failure_message(
    decode_json_body(
      "{\"unknown\":[1,{\"nested\":null}],\"partialSuccess\":{\"rejectedSpans\":\"1\"},\"more\":true}",
    ),
  )
  assert_true(message.contains("rejected 1 span(s)"))
}

///|
test "json_decode_rejects_malformed_numbers_in_unknown_fields" {
  for body in [
    "{\"unknown\":1e}",
    "{\"unknown\":1e+}",
    "{\"unknown\":-}",
    "{\"unknown\":1.}",
    "{\"unknown\":1.2.3}",
    "{\"unknown\":--1}",
    "{\"unknown\":1+2}",
    "{\"unknown\":01}",
  ] {
    assert_false(decode_json_body(body).is_success())
  }
}

///|
test "json_decode_rejects_plus_sign_and_leading_zero_numbers" {
  for body in [
    "{\"partialSuccess\":{\"rejectedSpans\":\"+5\"}}",
    "{\"partialSuccess\":{\"rejectedSpans\":+5}}",
    "{\"partialSuccess\":{\"rejectedSpans\":01}}",
    "{\"partialSuccess\":{\"rejectedSpans\":-01}}",
    "{\"partialSuccess\":{\"rejectedSpans\":00}}",
    "{\"partialSuccess\":{\"rejectedSpans\":+0}}",
  ] {
    assert_false(decode_json_body(body).is_success())
  }
}

///|
test "json_decode_partial_success_skips_unknown_members" {
  let message = json_failure_message(
    decode_json_body(
      "{\"partialSuccess\":{\"extra\":{\"a\":[true,false]},\"rejectedSpans\":\"4\"}}",
    ),
  )
  assert_true(message.contains("rejected 4 span(s)"))
}

///|
test "json_decode_tolerates_whitespace" {
  let message = json_failure_message(
    decode_json_body(
      "  {  \n  \"partialSuccess\" : { \"rejectedSpans\" : \"1\" } }  ",
    ),
  )
  assert_true(message.contains("rejected 1 span(s)"))
}

///|
test "json_decode_malformed_bodies_fail" {
  for
    body in [
      "{", "}", "not json", "false", "{\"partialSuccess\":", "{\"partialSuccess\":{\"errorMessage\":",
      "{\"partialSuccess\":{\"rejectedSpans\":}}", "{\"partialSuccess\":{\"rejectedSpans\":\"1\"}",
      "{\"partialSuccess\":{\"rejectedSpans\":\"1\"}}}", "{} trailing", "{\"partialSuccess\":{\"rejectedSpans\":\"x\"}}",
      "{\"partialSuccess\":{\"rejectedSpans\":\"-1\"}}", "{\"partialSuccess\":{\"errorMessage\":\"unterminated}}",
    ] {
    assert_false(decode_json_body(body).is_success())
  }
}

///|
test "json_decode_rejects_deep_nesting" {
  let sb = StringBuilder()
  sb.write_string("{\"unknown\":")
  let mut i = 0
  while i < 80 {
    sb.write_char('[')
    i = i + 1
  }
  let mut j = 0
  while j < 80 {
    sb.write_char(']')
    j = j + 1
  }
  sb.write_char('}')
  assert_false(decode_json_body(sb.to_string()).is_success())
}

///|
test "json_decode_handles_unicode_escapes" {
  let message = json_failure_message(
    decode_json_body(
      "{\"partialSuccess\":{\"errorMessage\":\"\\u0041\\u00e9\\uD83D\\uDE00\"}}",
    ),
  )
  assert_true(message.contains("A\u{00E9}\u{1F600}"))
}
