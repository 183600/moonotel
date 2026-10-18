// Tests for OTEL_EXPORTER_OTLP_* environment precedence and for surfacing
// `partial_success` from the OTLP response body.

///|
fn unset_otlp_env() -> Unit {
  @env.unset_env_var("OTEL_EXPORTER_OTLP_ENDPOINT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_HEADERS")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_HEADERS")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_COMPRESSION")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_COMPRESSION")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_PROTOCOL")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_PROTOCOL")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TIMEOUT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT")
}

///|
fn body_transport(body : Bytes) -> @otlp.Transport {
  fn(_url, _headers, _payload) { { status_code: 200, body, } }
}

///|
test "traces_endpoint_takes_precedence_over_generic" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_ENDPOINT", "http://generic:4318")
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://specific:4318/custom/traces",
  )
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.traces_url(), "http://specific:4318/custom/traces")
}

///|
test "generic_endpoint_stays_the_base_url_when_traces_endpoint_is_set" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_ENDPOINT", "http://generic:4318")
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://specific:4318/custom/traces",
  )
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.endpoint, "http://generic:4318")
  assert_eq(config.traces_endpoint, Some("http://specific:4318/custom/traces"))
  assert_eq(config.traces_url(), "http://specific:4318/custom/traces")
}

///|
test "generic_endpoint_is_used_when_traces_endpoint_is_absent" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_ENDPOINT", "http://generic:4318")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.traces_url(), "http://generic:4318/v1/traces")
}

///|
test "traces_headers_override_generic_headers" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_HEADERS", "x-generic=1,x-shared=generic")
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_TRACES_HEADERS", "x-shared=traces,x-traces=2",
  )
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.headers.get("x-generic"), Some("1"))
  assert_eq(config.headers.get("x-shared"), Some("traces"))
  assert_eq(config.headers.get("x-traces"), Some("2"))
}

///|
test "header_values_are_percent_decoded" {
  unset_otlp_env()
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_HEADERS", "Authorization=Bearer%20abc%2Cdef,x-raw=100%25,x-mix=café%20%E2%98%95",
  )
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.headers.get("Authorization"), Some("Bearer abc,def"))
  assert_eq(config.headers.get("x-raw"), Some("100%"))
  assert_eq(config.headers.get("x-mix"), Some("café ☕"))
}

///|
test "header_keys_are_not_percent_decoded" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_HEADERS", "x%2Dkey=value")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.headers.get("x%2Dkey"), Some("value"))
  assert_eq(config.headers.get("x-key"), None)
}

///|
test "invalid_header_value_escapes_are_kept_verbatim" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_HEADERS", "x-bad=%zz,x-short=%4")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.headers.get("x-bad"), Some("%zz"))
  assert_eq(config.headers.get("x-short"), Some("%4"))
}

///|
test "traces_compression_takes_precedence" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_COMPRESSION", "gzip")
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_COMPRESSION", "none")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.compression, "none")
}

///|
test "traces_timeout_takes_precedence" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_TIMEOUT", "5000")
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT", "2500")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.timeout_millis, 2500)
}

///|
test "traces_protocol_takes_precedence" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_PROTOCOL", "grpc")
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_PROTOCOL", "http/protobuf")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.protocol, "http/protobuf")
}

///|
test "generic_protocol_is_used_when_traces_protocol_is_absent" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_PROTOCOL", "grpc")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.protocol, "grpc")
}

///|
test "protocol_defaults_to_http_protobuf" {
  unset_otlp_env()
  let config = @otlp.OtlpHttpConfig::from_env()
  assert_eq(config.protocol, "http/protobuf")
  let explicit = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318")
  assert_eq(explicit.protocol, "http/protobuf")
}

///|
test "unsupported_protocol_fails_export" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    protocol="grpc",
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, body_transport(b""))
  let result = exporter.export_spans([test_span()])
  assert_false(result.is_success())
}

///|
test "invalid_timeout_falls_back_to_default" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT", "not-a-number")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.timeout_millis, 10000)
}

///|
test "export_surfaces_partial_success" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318")
  let exporter = @otlp.OtlpHttpExporter::new(
    config,
    body_transport(b"\x0A\x02\x08\x03"),
  )
  let result = exporter.export_spans([test_span()])
  assert_false(result.is_success())
}

///|
test "export_succeeds_on_empty_partial_success" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318")
  let exporter = @otlp.OtlpHttpExporter::new(
    config,
    body_transport(b"\x0A\x00"),
  )
  let result = exporter.export_spans([test_span()])
  assert_true(result.is_success())
}

///|
test "export_fails_on_malformed_response_body" {
  let config = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318")
  let exporter = @otlp.OtlpHttpExporter::new(config, body_transport(b"\xFF"))
  let result = exporter.export_spans([test_span()])
  assert_false(result.is_success())
}
