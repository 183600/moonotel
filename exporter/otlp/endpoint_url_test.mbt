// Endpoint URL construction: the generic endpoint is a base URL, while the
// traces-specific endpoint is already a full URL.

///|
test "generic endpoint gets v1/traces appended" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318")
  assert_eq(config.traces_url(), "http://collector:4318/v1/traces")
}

///|
test "trailing slash on the generic endpoint is handled" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318/")
  assert_eq(config.traces_url(), "http://collector:4318/v1/traces")
}

///|
test "a generic endpoint already ending in v1/traces is not doubled" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318/v1/traces",
  )
  assert_eq(config.traces_url(), "http://collector:4318/v1/traces")

  let with_slash = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318/v1/traces/",
  )
  assert_eq(with_slash.traces_url(), "http://collector:4318/v1/traces/")
}

///|
test "traces endpoint is used verbatim" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://generic:4318",
    traces_endpoint="http://specific:4318/custom/traces",
  )
  assert_eq(config.traces_url(), "http://specific:4318/custom/traces")
}

///|
test "traces endpoint without a path uses the root path" {
  let config = @otlp.OtlpHttpConfig::new(traces_endpoint="http://specific:4318")
  assert_eq(config.traces_url(), "http://specific:4318/")
  let with_query = @otlp.OtlpHttpConfig::new(
    traces_endpoint="http://specific:4318?tenant=acme",
  )
  assert_eq(config.traces_url(), "http://specific:4318/")
  assert_eq(with_query.traces_url(), "http://specific:4318/?tenant=acme")
  let with_fragment = @otlp.OtlpHttpConfig::new(
    traces_endpoint="http://specific:4318#fragment",
  )
  assert_eq(with_fragment.traces_url(), "http://specific:4318/#fragment")
}

///|
test "traces endpoint with a trailing slash or path is unchanged" {
  for
    url in [
      "http://specific:4318/", "http://specific:4318/custom/traces", "http://specific:4318/custom/traces?tenant=acme",
    ] {
    let config = @otlp.OtlpHttpConfig::new(traces_endpoint=url)
    assert_eq(config.traces_url(), url)
  }
}

// Relative endpoints have no authority that could be mistaken for a path.
// The signal path is appended to the path component, and a fragment or query
// stays at the end.

///|
test "relative generic endpoint gets the signal path" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="collector:4318/base")
  assert_eq(config.traces_url(), "collector:4318/base/v1/traces")
  assert_eq(config.request_url(), "collector:4318/base/v1/traces")

  let with_query = @otlp.OtlpHttpConfig::new(
    endpoint="/base?tenant=acme#section",
  )
  assert_eq(
    with_query.traces_url(),
    "/base/v1/traces?tenant=acme#section",
  )
  assert_eq(with_query.request_url(), "/base/v1/traces?tenant=acme")
}

///|
test "relative generic endpoint already ending in the signal path is unchanged" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="/v1/traces")
  assert_eq(config.traces_url(), "/v1/traces")
}
