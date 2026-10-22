// Timeout environment values are non-negative Int32 millisecond counts. A
// value outside that range is treated as not set, so the generic fallback (and
// finally the default) still applies.

///|
fn clear_timeout_variables() -> Unit {
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TIMEOUT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT")
}

///|
test "timeout_above_int32_range_falls_back_to_the_generic_value" {
  clear_timeout_variables()
  @env.set_env_var("OTEL_EXPORTER_OTLP_TIMEOUT", "2500")
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT", "2147483648")
  let config = @otlp.OtlpHttpConfig::from_env()
  clear_timeout_variables()
  assert_eq(config.timeout_millis, 2500)
}

///|
test "generic_timeout_above_int32_range_uses_the_default" {
  clear_timeout_variables()
  @env.set_env_var("OTEL_EXPORTER_OTLP_TIMEOUT", "999999999999999999999")
  let config = @otlp.OtlpHttpConfig::from_env()
  clear_timeout_variables()
  assert_eq(config.timeout_millis, 10000)
}

///|
test "timeout_at_the_int32_limit_is_preserved" {
  clear_timeout_variables()
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT", "2147483647")
  let config = @otlp.OtlpHttpConfig::from_env()
  clear_timeout_variables()
  assert_eq(config.timeout_millis, 2147483647)
}
