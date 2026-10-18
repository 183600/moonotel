// Exporter selection in `setup`: explicit `exporters` lists override the
// `OTEL_TRACES_EXPORTER` environment variable.

///|
test "setup_installs_a_console_processor_for_console_only" {
  @otel.shutdown_global_tracer_provider()
  let capture = capturing_transport()
  let provider = @otel.setup(
    service_name="console-facade",
    transport=capture.send(),
    exporters=["console"],
    use_batch=false,
  )
  assert_eq(provider.processor_count(), 1)
  let tracer = @otel.global_tracer("console-scope")
  let span = tracer.start_root_span("printed")
  span.end()
  // The OTLP exporter was not selected, so the transport is never used.
  assert_eq(capture.urls.length(), 0)
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}

///|
test "setup_installs_console_and_otlp_processors_together" {
  @otel.shutdown_global_tracer_provider()
  let capture = capturing_transport()
  let provider = @otel.setup(
    service_name="console-otlp-facade",
    endpoint="http://collector:4318",
    transport=capture.send(),
    exporters=["console", "otlp"],
    use_batch=false,
  )
  assert_eq(provider.processor_count(), 2)
  let tracer = @otel.global_tracer("console-otlp-scope")
  let span = tracer.start_root_span("printed-and-sent")
  span.end()
  assert_eq(capture.urls.length(), 1)
  assert_eq(capture.urls[0], "http://collector:4318/v1/traces")
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}

///|
test "setup_installs_no_processor_when_only_unknown_exporters_are_listed" {
  @otel.shutdown_global_tracer_provider()
  let capture = capturing_transport()
  let provider = @otel.setup(
    service_name="unknown-exporter-facade",
    transport=capture.send(),
    exporters=["zipkin"],
    use_batch=false,
  )
  assert_eq(provider.processor_count(), 0)
  let tracer = @otel.global_tracer("unknown-exporter-scope")
  let span = tracer.start_root_span("recorded-only")
  assert_true(span.is_recording())
  span.end()
  assert_eq(capture.urls.length(), 0)
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}

///|
test "setup_with_none_exporter_list_installs_nothing" {
  @otel.shutdown_global_tracer_provider()
  let capture = capturing_transport()
  let provider = @otel.setup(
    service_name="none-exporter-facade",
    transport=capture.send(),
    exporters=["none"],
    use_batch=false,
  )
  assert_eq(provider.processor_count(), 0)
  let tracer = @otel.global_tracer("none-exporter-scope")
  let span = tracer.start_root_span("recorded-only")
  span.end()
  assert_eq(capture.urls.length(), 0)
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}
