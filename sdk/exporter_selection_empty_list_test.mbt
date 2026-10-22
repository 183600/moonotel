// `OTEL_TRACES_EXPORTER` lists may contain empty entries. A value made only
// of separators and whitespace carries no exporter name and therefore has to
// behave like an unset/blank variable: select the default OTLP exporter.

///|
test "separator_only_exporter_list_uses_the_default" {
  @env.set_env_var("OTEL_TRACES_EXPORTER", " , , ")
  assert_true(@sdk.traces_exporter_enabled("otlp"))
  assert_false(@sdk.traces_exporter_enabled("console"))
  assert_false(@sdk.traces_exporter_disabled())
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
}
