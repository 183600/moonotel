// Direct coverage for the public size-limit helpers used by the exporter and
// the async OTLP transport.

///|
test "normalize_size_limit falls back for missing and non-positive limits" {
  assert_eq(@otlp.normalize_size_limit(None, 100), 100)
  assert_eq(@otlp.normalize_size_limit(Some(0), 100), 100)
  assert_eq(@otlp.normalize_size_limit(Some(-1), 100), 100)
  assert_eq(@otlp.normalize_size_limit(Some(101), 100), 101)
}

///|
test "request_size_limit_failure labels default and custom limits" {
  match @otlp.request_size_limit_failure(
    @otlp.OTLP_DEFAULT_MAX_REQUEST_SIZE,
  ) {
    @sdk.ExportFailure(message) => {
      assert_true(message.contains("64 MiB"))
      assert_false(message.contains("67108864-byte"))
    }
    @sdk.ExportSuccess => abort("expected a default request size-limit failure")
  }
  match @otlp.request_size_limit_failure(1234) {
    @sdk.ExportFailure(message) => assert_true(message.contains("1234-byte"))
    @sdk.ExportSuccess => abort("expected a custom request size-limit failure")
  }
}