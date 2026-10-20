// Blackbox tests for the OTLP/HTTP response decoder and trace endpoint
// resolution.

///|
test "decode_empty_body_is_success" {
  assert_eq(@otlp.decode_export_response(b""), @sdk.ExportSuccess)
}

///|
test "decode_partial_success_rejected_spans" {
  // ExportTraceServiceResponse { partial_success { rejected_spans = 3 } }
  let body : Bytes = b"\x0a\x02\x08\x03"
  let result = @otlp.decode_export_response(body)
  assert_false(result.is_success())
}

///|
test "decode_partial_success_error_message" {
  // ExportTraceServiceResponse { partial_success { error_message = "warn" } }
  let body : Bytes = b"\x0a\x06\x12\x04warn"
  let result = @otlp.decode_export_response(body)
  assert_false(result.is_success())
}

///|
test "decode_partial_success_rejected_and_message" {
  // partial_success { rejected_spans = 3, error_message = "bad" }
  let body : Bytes = b"\x0a\x07\x08\x03\x12\x03bad"
  let result = @otlp.decode_export_response(body)
  assert_false(result.is_success())
}

///|
test "decode_empty_partial_success_is_success" {
  // rejected_spans = 0 and an empty message is equivalent to full success.
  let body : Bytes = b"\x0a\x02\x08\x00"
  assert_eq(@otlp.decode_export_response(body), @sdk.ExportSuccess)
}

///|
test "decode_repeated_partial_success_last_wins" {
  // Repeated `partial_success` messages merge; later scalar fields overwrite
  // earlier ones, including an explicit zero and an empty message.
  let body : Bytes = b"\x0a\x07\x08\x03\x12\x03bad\x0a\x04\x08\x00\x12\x00"
  assert_eq(@otlp.decode_export_response(body), @sdk.ExportSuccess)
}

///|
test "decode_truncated_body_is_failure" {
  assert_false(@otlp.decode_export_response(b"\x0a").is_success())
  assert_false(@otlp.decode_export_response(b"\x0a\x05\x08").is_success())
}

///|
test "decode_rejects_oversized_response_body" {
  // Per the OTLP spec the client must limit the response body size (4 MiB by
  // recommendation) and treat an oversized body as a non-retryable failure.
  let oversized : Bytes = Bytes::make(4194305, b'\x00')
  match @otlp.decode_export_response(oversized) {
    @sdk.ExportFailure(message) => assert_true(message.contains("4 MiB"))
    @sdk.ExportSuccess => abort("expected an export failure")
  }
}

///|
test "decode_invalid_wire_types_is_failure" {
  // Field 1 with wire type 3 (start group) / 6 / 7 never occurs in this
  // message and must be rejected instead of silently accepted.
  assert_false(@otlp.decode_export_response(b"\x0b").is_success())
  assert_false(@otlp.decode_export_response(b"\x0e").is_success())
  assert_false(@otlp.decode_export_response(b"\x0f").is_success())
  // The same applies to an invalid wire type inside partial_success.
  assert_false(@otlp.decode_export_response(b"\x0a\x01\x0b").is_success())
}

///|
test "decode_ignores_unknown_fields" {
  // Unknown varint field 4 followed by partial_success { rejected_spans = 1 }.
  let body : Bytes = b"\x20\x01\x0a\x02\x08\x01"
  let result = @otlp.decode_export_response(body)
  assert_false(result.is_success())
}

///|
test "traces_endpoint_env_used_verbatim" {
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://collector:4318/v1/traces",
  )
  let config = @otlp.OtlpHttpConfig::from_env()
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
  assert_eq(config.traces_url(), "http://collector:4318/v1/traces")
}

///|
test "traces_endpoint_env_custom_path_kept" {
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://collector:4318/custom/traces",
  )
  let config = @otlp.OtlpHttpConfig::from_env()
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
  assert_eq(config.traces_url(), "http://collector:4318/custom/traces")
}
