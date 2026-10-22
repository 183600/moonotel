// Repeated `partialSuccess` fields in an OTLP/JSON response are merged like a
// repeated protobuf message field: fields present in a later occurrence
// overwrite earlier ones, while absent fields keep their earlier value.

///|
fn decode_merge_body(text : String) -> @sdk.ExportResult {
  @otlp.decode_export_response_json(@utf8.encode(text))
}

///|
fn merge_failure_message(result : @sdk.ExportResult) -> String {
  match result {
    @sdk.ExportFailure(message) => message
    @sdk.ExportSuccess => abort("expected an export failure")
  }
}

///|
test "json_repeated_partial_success_merges_missing_fields" {
  // The later occurrence only sets `errorMessage`, so `rejectedSpans` from the
  // first occurrence must be retained.
  let message = merge_failure_message(
    decode_merge_body(
      "{\"partialSuccess\":{\"rejectedSpans\":\"3\",\"errorMessage\":\"bad\"},\"partialSuccess\":{\"errorMessage\":\"still bad\"}}",
    ),
  )
  assert_true(message.contains("rejected 3 span(s)"))
  assert_true(message.contains("still bad"))
}

///|
test "json_repeated_partial_success_keeps_earlier_error_message" {
  // A later occurrence that only sets `rejectedSpans` must not clear the
  // earlier error message.
  let message = merge_failure_message(
    decode_merge_body(
      "{\"partialSuccess\":{\"rejectedSpans\":\"1\",\"errorMessage\":\"first\"},\"partialSuccess\":{\"rejectedSpans\":\"2\"}}",
    ),
  )
  assert_true(message.contains("rejected 2 span(s)"))
  assert_true(message.contains("first"))
}

///|
test "json_repeated_partial_success_empty_object_keeps_earlier_values" {
  // An empty partial-success object contributes no fields, so the earlier
  // rejection is still reported.
  let message = merge_failure_message(
    decode_merge_body(
      "{\"partialSuccess\":{\"rejectedSpans\":\"4\"},\"partialSuccess\":{}}",
    ),
  )
  assert_true(message.contains("rejected 4 span(s)"))
}

///|
test "json_repeated_partial_success_explicit_defaults_clear_earlier_values" {
  // An explicit zero count and an explicit empty message overwrite the earlier
  // values, making the response a full success.
  assert_eq(
    decode_merge_body(
      "{\"partialSuccess\":{\"rejectedSpans\":3,\"errorMessage\":\"bad\"},\"partialSuccess\":{\"rejectedSpans\":0,\"errorMessage\":\"\"}}",
    ),
    @sdk.ExportSuccess,
  )
}

///|
test "json_repeated_partial_success_null_resets_to_defaults" {
  // JSON `null` denotes an empty message, so it clears earlier values.
  assert_eq(
    decode_merge_body(
      "{\"partialSuccess\":{\"rejectedSpans\":5,\"errorMessage\":\"bad\"},\"partialSuccess\":null}",
    ),
    @sdk.ExportSuccess,
  )
}
