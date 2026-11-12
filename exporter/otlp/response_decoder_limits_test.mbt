///|
test "decode_export_response honors a custom response size limit" {
  let body = b"\x0A\x00"
  let result = @otlp.decode_export_response(body, max_size=1)
  match result {
    @sdk.ExportFailure(message) => assert_true(message.contains("1-byte"))
    @sdk.ExportSuccess => abort("expected a size-limit failure")
  }
  assert_eq(@otlp.decode_export_response(body, max_size=2), @sdk.ExportSuccess)
}

///|
test "decode_export_response_json honors a custom response size limit" {
  let body = b"{}"
  let result = @otlp.decode_export_response_json(body, max_size=1)
  match result {
    @sdk.ExportFailure(message) => assert_true(message.contains("1-byte"))
    @sdk.ExportSuccess => abort("expected a size-limit failure")
  }
  assert_eq(
    @otlp.decode_export_response_json(body, max_size=2),
    @sdk.ExportSuccess,
  )
}

///|
test "decode_export_response treats non-positive limits as the default" {
  let body = b"\x0A\x00"
  assert_eq(
    @otlp.decode_export_response(body, max_size=0),
    @sdk.ExportSuccess,
  )
  assert_eq(
    @otlp.decode_export_response_json(b"{}", max_size=-1),
    @sdk.ExportSuccess,
  )
}

///|
test "OTLP size limit defaults match the specification" {
  assert_eq(@otlp.OTLP_DEFAULT_MAX_REQUEST_SIZE, 67108864)
  assert_eq(@otlp.OTLP_DEFAULT_MAX_RESPONSE_SIZE, 4194304)
}
