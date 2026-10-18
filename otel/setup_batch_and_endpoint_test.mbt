// `setup` defaults to the batch processor and honors the environment trace
// endpoint when no explicit endpoint argument is given.

///|
test "setup_defaults_to_batch_and_env_traces_endpoint" {
  @otel.shutdown_global_tracer_provider()
  @env.set_env_var("OTEL_EXPORTER_OTLP_ENDPOINT", "http://collector:4318")
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://collector:4318/env/traces",
  )
  let capture = capturing_transport()
  let provider = @otel.setup(
    service_name="batch-facade",
    transport=capture.send(),
  )
  @env.unset_env_var("OTEL_EXPORTER_OTLP_ENDPOINT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
  let tracer = @otel.global_tracer("batch-scope")
  let span = tracer.start_root_span("batched")
  span.end()
  // The default batch size and flush interval keep the span queued.
  assert_eq(capture.urls.length(), 0)
  provider.shutdown()
  assert_eq(capture.urls.length(), 1)
  assert_eq(capture.urls[0], "http://collector:4318/env/traces")
  @otel.shutdown_global_tracer_provider()
}
