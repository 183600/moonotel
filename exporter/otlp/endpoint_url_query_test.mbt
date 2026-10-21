///|
test "query string stays after the appended v1/traces path" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318?token=secret",
  )
  assert_eq(
    config.traces_url(),
    "http://collector:4318/v1/traces?token=secret",
  )
}

///|
test "fragment stays after the appended v1/traces path" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318/base#section",
  )
  assert_eq(
    config.traces_url(),
    "http://collector:4318/base/v1/traces#section",
  )
}

///|
test "trailing slash before a query produces a single v1/traces" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318/?token=secret",
  )
  assert_eq(
    config.traces_url(),
    "http://collector:4318/v1/traces?token=secret",
  )
}

///|
test "full v1/traces URL with a query is not doubled" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318/v1/traces?token=secret",
  )
  assert_eq(
    config.traces_url(),
    "http://collector:4318/v1/traces?token=secret",
  )
}

///|
test "full v1/traces URL with a slash and query is not doubled" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318/v1/traces/?token=secret",
  )
  assert_eq(
    config.traces_url(),
    "http://collector:4318/v1/traces/?token=secret",
  )
}

///|
test "query before a fragment stays after the appended path" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318/base?token=secret#section",
  )
  assert_eq(
    config.traces_url(),
    "http://collector:4318/base/v1/traces?token=secret#section",
  )
}
