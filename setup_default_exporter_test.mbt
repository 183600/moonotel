// `setup` needs a transport to send OTLP payloads. When the OTLP exporter is
// selected but no transport is available the console exporter is installed
// instead, so that spans are not dropped silently.

///|
test "setup_without_transport_installs_the_console_exporter" {
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
  @moonotel.shutdown_global_tracer_provider()
  let provider = @moonotel.setup(service_name="default-facade")
  assert_eq(provider.processor_count(), 1)
  let tracer = @moonotel.global_tracer("default-scope")
  let span = tracer.start_root_span("printed")
  span.end()
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "setup_without_transport_and_console_exporter_installs_one_processor" {
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
  @moonotel.shutdown_global_tracer_provider()
  let provider = @moonotel.setup(service_name="default-console-facade", exporters=[
    "console",
  ])
  assert_eq(provider.processor_count(), 1)
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "setup_without_transport_and_none_exporter_installs_nothing" {
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
  @moonotel.shutdown_global_tracer_provider()
  let provider = @moonotel.setup(service_name="default-none-facade", exporters=[
    "none",
  ])
  assert_eq(provider.processor_count(), 0)
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "setup_without_transport_and_unknown_exporter_installs_nothing" {
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
  @moonotel.shutdown_global_tracer_provider()
  let provider = @moonotel.setup(service_name="default-unknown-facade", exporters=[
    "zipkin",
  ])
  assert_eq(provider.processor_count(), 0)
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "setup_without_transport_honours_a_disabled_exporter_variable" {
  @env.set_env_var("OTEL_TRACES_EXPORTER", "none")
  @moonotel.shutdown_global_tracer_provider()
  let provider = @moonotel.setup(service_name="default-disabled-facade")
  assert_eq(provider.processor_count(), 0)
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
}
