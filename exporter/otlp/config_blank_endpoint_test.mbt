// Blank programmatic endpoint values behave like blank environment values:
// the generic endpoint falls back to the default base URL, and a blank
// signal-specific endpoint is treated as unset.

///|
test "blank_programmatic_endpoint_uses_the_default" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="")
  assert_eq(config.endpoint, "http://localhost:4318")
  assert_eq(config.traces_endpoint, None)
  assert_eq(config.traces_url(), "http://localhost:4318/v1/traces")
  let whitespace = @otlp.OtlpHttpConfig::new(endpoint="  \t ")
  assert_eq(whitespace.endpoint, "http://localhost:4318")
}

///|
test "blank_programmatic_traces_endpoint_is_treated_as_unset" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    traces_endpoint="   ",
  )
  assert_eq(config.traces_endpoint, None)
  assert_eq(config.traces_url(), "http://collector:4318/v1/traces")
}

///|
test "programmatic_endpoints_are_trimmed" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="  http://generic:4318  ",
    traces_endpoint=" http://specific:4318/custom/traces ",
  )
  assert_eq(config.endpoint, "http://generic:4318")
  assert_eq(
    config.traces_url(),
    "http://specific:4318/custom/traces",
  )
}
