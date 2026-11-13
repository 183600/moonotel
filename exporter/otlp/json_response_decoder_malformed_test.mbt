// Malformed OTLP/JSON response bodies must be rejected instead of being
// silently accepted as a successful export.

///|
fn decode_malformed_response_body(text : String) -> @sdk.ExportResult {
  @otlp.decode_export_response_json(@utf8.encode(text))
}

///|
test "json_decode_skips_escaped_unknown_member_names" {
  assert_eq(
    decode_malformed_response_body("{\"unknown\\u0041\":1}"),
    @sdk.ExportSuccess,
  )
}

///|
test "json_decode_rejects_malformed_nested_unknown_values" {
  for
    body in [
      "{\"unknown\":[1,]}", "{\"unknown\":[1 2]}", "{\"unknown\":[1", "{\"unknown\":{\"a\":1,}}",
      "{\"unknown\":{\"a\" 1}}", "{\"unknown\":{\"a\":1", "{\"unknown\":tru}", "{\"unknown\":fals}",
      "{\"unknown\":nul}", "{\"unknown\":.5}", "{\"unknown\":+1}", "{\"unknown\":01}",
      "{\"unknown\":1.}", "{\"unknown\":\"\\x\"}", "{\"unknown\":\"\\u12\"}", "{\"unknown\":\"\\uZZZZ\"}",
      "{\"unknown\":\"a\nb\"}",
    ] {
    assert_false(decode_malformed_response_body(body).is_success())
  }
}

///|
test "json_decode_rejects_malformed_partial_success_values" {
  for
    body in [
      "{\"partialSuccess\":1}", "{\"partialSuccess\":\"value\"}", "{\"partialSuccess\":[]}",
      "{\"partialSuccess\":true}", "{\"partialSuccess\":{\"rejectedSpans\":{}}}",
      "{\"partialSuccess\":{\"rejectedSpans\":[]}}", "{\"partialSuccess\":{\"rejectedSpans\":true}}",
      "{\"partialSuccess\":{\"errorMessage\":1}}", "{\"partialSuccess\":{\"errorMessage\":true}}",
      "{\"partialSuccess\":{\"rejectedSpans\":\"\"}}", "{\"partialSuccess\":{\"rejectedSpans\":\"-\"}}",
      "{\"partialSuccess\":{\"rejectedSpans\":\"9223372036854775809\"}}", "{\"partialSuccess\":{\"rejectedSpans\":\"-9223372036854775809\"}}",
      "{\"partialSuccess\":{\"rejectedSpans\":\"1.5\"}}", "{\"partialSuccess\":{\"rejectedSpans\":9223372036854775809}}",
      "{\"partialSuccess\":{\"rejectedSpans\":-9223372036854775809}}", "{\"partialSuccess\":{\"rejectedSpans\":1.5}}",
      "{\"partialSuccess\":{\"rejectedSpans\":1e-1}}", "{\"partialSuccess\":{\"rejectedSpans\":1e19}}",
      "{\"partialSuccess\":{\"rejectedSpans\":}}", "{\"partialSuccess\":{\"rejectedSpans\":",
      "{\"partialSuccess\":{\"rejectedSpans\":nul}}", "{\"partialSuccess\":{\"rejectedSpans\":1",
      "{\"partialSuccess\":{\"rejectedSpans\":1 2}}", "{\"partialSuccess\":{\"rejectedSpans\":1,",
      "{\"partialSuccess\":{\"rejectedSpans\":1,\"errorMessage\":", "{\"partialSuccess\":{\"errorMessage\":",
      "{\"partialSuccess\":{\"errorMessage\":\"x\"", "{\"partialSuccess\":{\"errorMessage\":\"x\"}",
      "{\"partialSuccess\":null",
    ] {
    assert_false(decode_malformed_response_body(body).is_success())
  }
}

///|
test "json_decode_accepts_structurally_valid_unknown_containers" {
  for
    body in ["{\"unknown\":{}}", "{\"unknown\":[]}", "{\"unknown\":{\"a\":[]}}"] {
    assert_true(decode_malformed_response_body(body).is_success())
  }
}

///|
test "json_decode_accepts_whole_number_exponent_forms" {
  for
    body in [
      "{\"partialSuccess\":{\"rejectedSpans\":1e+2}}", "{\"partialSuccess\":{\"rejectedSpans\":1.0e2}}",
    ] {
    match decode_malformed_response_body(body) {
      @sdk.ExportFailure(message) =>
        assert_true(message.contains("rejected 100 span(s)"))
      @sdk.ExportSuccess => abort("expected a partial-success failure")
    }
  }
}

///|
test "json_decode_rejects_structurally_malformed_partial_success" {
  for
    body in [
      "{\"partialSuccess\":nul}", "{\"partialSuccess\":{1:2}}", "{\"partialSuccess\":{\"rejectedSpans\" 1}}",
      "{\"partialSuccess\":{\"rejectedSpans\":1,2}}", "{\"partialSuccess\":{\"errorMessage\":nul}}",
      "{\"partialSuccess\":{\"extra\":tru}}", "{\"partialSuccess\":{},", "{\"partialSuccess\":{",
    ] {
    assert_false(decode_malformed_response_body(body).is_success())
  }
}
