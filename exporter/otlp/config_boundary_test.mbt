// Boundary behavior of the programmatic `OtlpHttpConfig::new` constructor:
// invalid values fall back to the same defaults as the environment path.

///|
test "config_new_negative_timeout_falls_back_to_default" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    timeout_millis=-1,
  )
  assert_eq(config.timeout_millis, 10000)
}

///|
test "config_new_zero_timeout_means_no_timeout" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    timeout_millis=0,
  )
  assert_eq(config.timeout_millis, 0)
}

///|
test "config_new_blank_compression_and_protocol_use_defaults" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    compression="  ",
    protocol="\t",
  )
  assert_eq(config.compression, "none")
  assert_eq(config.protocol, @otlp.OTLP_HTTP_PROTOBUF_PROTOCOL)
}

///|
test "config_new_preserves_positive_timeout" {
  // The constructor only accepts an integer, so the boundary values are
  // negative (invalid) and zero (explicitly no timeout).
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    timeout_millis=1,
  )
  assert_eq(config.timeout_millis, 1)
}
