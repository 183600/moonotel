// `OTEL_TRACES_EXPORTER=none` disables the trace exporter.

///|
test "traces_exporter_none_is_detected_case_insensitively" {
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
  assert_false(@sdk.traces_exporter_disabled())
  @env.set_env_var("OTEL_TRACES_EXPORTER", "none")
  assert_true(@sdk.traces_exporter_disabled())
  @env.set_env_var("OTEL_TRACES_EXPORTER", " NONE ")
  assert_true(@sdk.traces_exporter_disabled())
  @env.set_env_var("OTEL_TRACES_EXPORTER", "otlp")
  assert_false(@sdk.traces_exporter_disabled())
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
}
