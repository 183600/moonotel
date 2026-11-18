// A generic endpoint is a base URL: only the path component decides whether
// `/v1/traces` is already present. A host literally named `v1` followed by a
// `/traces` path must still get the signal path appended.

///|
test "generic endpoint with host named v1 appends the signal path" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="http://v1/traces")
  assert_eq(config.traces_url(), "http://v1/traces/v1/traces")
}

///|
test "generic endpoint with host named v1 keeps query and fragment" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://v1/traces?tenant=acme#section",
  )
  assert_eq(
    config.traces_url(),
    "http://v1/traces/v1/traces?tenant=acme#section",
  )
}

///|
test "generic network path with host named v1 appends the signal path" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="//v1/traces")
  assert_eq(config.traces_url(), "//v1/traces/v1/traces")
}

///|
test "a signal path in the path component is still not doubled" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318/tenant/v1/traces",
  )
  assert_eq(config.traces_url(), "http://collector:4318/tenant/v1/traces")
}
