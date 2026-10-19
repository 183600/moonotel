// Tests for JSON `null` handling in the OTLP/JSON response decoder. Proto3
// JSON accepts `null` for any field and treats it as the field's default.

///|
test "json_decode_null_partial_success_is_success" {
  assert_eq(
    @otlp.decode_export_response_json(
      @utf8.encode("{\"partialSuccess\":null}"),
    ),
    @sdk.ExportSuccess,
  )
  assert_eq(
    @otlp.decode_export_response_json(
      @utf8.encode("{\"partialSuccess\" : null }"),
    ),
    @sdk.ExportSuccess,
  )
}

///|
test "json_decode_null_partial_success_members_are_defaults" {
  assert_eq(
    @otlp.decode_export_response_json(
      @utf8.encode(
        "{\"partialSuccess\":{\"rejectedSpans\":null,\"errorMessage\":null}}",
      ),
    ),
    @sdk.ExportSuccess,
  )
}

///|
test "json_decode_null_members_do_not_hide_a_nonzero_rejected_count" {
  let result = @otlp.decode_export_response_json(
    @utf8.encode(
      "{\"partialSuccess\":{\"rejectedSpans\":null,\"errorMessage\":\"boom\"}}",
    ),
  )
  match result {
    @sdk.ExportFailure(message) => assert_true(message.contains("boom"))
    @sdk.ExportSuccess => abort("expected an export failure")
  }
}
