// Blank environment values fall back to the generic variable or the default.

test "blank_generic_compression_falls_back_to_none" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_COMPRESSION", "   ")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.compression, "none")
}

test "blank_traces_compression_falls_back_to_generic" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_COMPRESSION", "gzip")
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_COMPRESSION", " ")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.compression, "gzip")
}

test "blank_traces_protocol_falls_back_to_default" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_PROTOCOL", "  ")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.protocol, "http/protobuf")
}

test "blank_generic_protocol_falls_back_to_default" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_PROTOCOL", "\t")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.protocol, "http/protobuf")
}

test "header_without_equals_is_skipped" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_HEADERS", "novalue,x=1")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.headers.get("novalue"), None)
  assert_eq(config.headers.get("x"), Some("1"))
}

test "non_ascii_percent_escape_is_kept_verbatim" {
  unset_otlp_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_HEADERS", "x=%éA")
  let config = @otlp.OtlpHttpConfig::from_env()
  unset_otlp_env()
  assert_eq(config.headers.get("x"), Some("%éA"))
}
