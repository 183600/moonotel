// Blank header environment values are treated as unset, consistently with the
// other OTLP environment variables.

///|
test "blank_signal_specific_headers_fall_back_to_generic_headers" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_HEADERS", "x-generic=1")
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_HEADERS", " \t ")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.headers.get("x-generic"), Some("1"))
}

///|
test "blank_generic_headers_keep_signal_specific_headers" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_HEADERS", "  ")
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_HEADERS", "x-traces=2")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.headers.get("x-traces"), Some("2"))
  assert_eq(config.headers.length(), 1)
}
