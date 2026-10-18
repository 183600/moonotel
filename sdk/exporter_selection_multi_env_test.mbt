// Exporter selection: explicit lists and the `OTEL_TRACES_EXPORTER` variable.

///|
test "exporter_selected_matches_explicit_lists_case_insensitively" {
  assert_true(@sdk.exporter_selected(Some(["otlp"]), "otlp"))
  assert_true(@sdk.exporter_selected(Some([" Console ", "otlp"]), "console"))
  assert_true(@sdk.exporter_selected(Some(["console"]), "CONSOLE"))
  assert_false(@sdk.exporter_selected(Some(["console"]), " Otlp "))
  assert_true(@sdk.exporter_selected(Some(["zipkin"]), "zipkin"))
  assert_false(@sdk.exporter_selected(Some(["zipkin"]), "otlp"))
  assert_false(@sdk.exporter_selected(Some([]), "otlp"))
}

///|
test "exporter_selected_honors_none_inside_lists" {
  assert_false(@sdk.exporter_selected(Some(["none"]), "otlp"))
  assert_false(@sdk.exporter_selected(Some(["console", " NONE "]), "console"))
  assert_false(@sdk.exporter_selected(Some(["none"]), "console"))
}

///|
test "exporter_selected_reads_the_environment_when_no_list_is_given" {
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
  assert_true(@sdk.exporter_selected(None, "otlp"))
  assert_false(@sdk.exporter_selected(None, "console"))
  @env.set_env_var("OTEL_TRACES_EXPORTER", "console,otlp")
  assert_true(@sdk.exporter_selected(None, "console"))
  assert_true(@sdk.exporter_selected(None, "otlp"))
  @env.set_env_var("OTEL_TRACES_EXPORTER", "none")
  assert_false(@sdk.exporter_selected(None, "otlp"))
  assert_false(@sdk.exporter_selected(None, "console"))
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
}

///|
test "traces_exporter_enabled_defaults_to_otlp" {
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
  assert_true(@sdk.traces_exporter_enabled("otlp"))
  assert_false(@sdk.traces_exporter_enabled("console"))
  @env.set_env_var("OTEL_TRACES_EXPORTER", "   ")
  assert_true(@sdk.traces_exporter_enabled("otlp"))
  assert_false(@sdk.traces_exporter_enabled("console"))
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
}

///|
test "traces_exporter_disabled_detects_none_inside_a_list" {
  @env.set_env_var("OTEL_TRACES_EXPORTER", "console,none")
  assert_true(@sdk.traces_exporter_disabled())
  @env.set_env_var("OTEL_TRACES_EXPORTER", "console,otlp")
  assert_false(@sdk.traces_exporter_disabled())
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
}

///|
test "traces_exporter_enabled_parses_case_insensitive_lists" {
  @env.set_env_var("OTEL_TRACES_EXPORTER", " Console , otlp ,zipkin")
  assert_true(@sdk.traces_exporter_enabled("console"))
  assert_true(@sdk.traces_exporter_enabled("OTLP"))
  // A listed name is reported as requested even when the SDK does not
  // implement the exporter.
  assert_true(@sdk.traces_exporter_enabled("zipkin"))
  assert_false(@sdk.traces_exporter_enabled("jaeger"))
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
}
