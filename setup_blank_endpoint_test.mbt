// A blank `endpoint` argument of `setup` is treated like an unset endpoint:
// it must not replace the environment endpoint or hide an environment
// traces-specific endpoint.

///|
test "setup_blank_endpoint_uses_the_default_endpoint" {
  @moonotel.shutdown_global_tracer_provider()
  @env.unset_env_var("OTEL_EXPORTER_OTLP_ENDPOINT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
  let capture = capturing_transport()
  let provider = @moonotel.setup(
    service_name="blank-endpoint",
    endpoint="  \t ",
    transport=capture.send(),
    use_batch=false,
  )
  let tracer = @moonotel.global_tracer("blank-endpoint")
  tracer.start_root_span("op").end()
  assert_eq(capture.urls.length(), 1)
  assert_eq(capture.urls[0], "http://localhost:4318/v1/traces")
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "setup_blank_endpoint_keeps_the_environment_traces_endpoint" {
  @moonotel.shutdown_global_tracer_provider()
  @env.set_env_var("OTEL_EXPORTER_OTLP_ENDPOINT", "http://generic:4318")
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://specific:4318/custom/traces",
  )
  let capture = capturing_transport()
  let provider = @moonotel.setup(
    service_name="blank-endpoint-env",
    endpoint="",
    transport=capture.send(),
    use_batch=false,
  )
  let tracer = @moonotel.global_tracer("blank-endpoint-env")
  tracer.start_root_span("op").end()
  @env.unset_env_var("OTEL_EXPORTER_OTLP_ENDPOINT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
  assert_eq(capture.urls.length(), 1)
  assert_eq(capture.urls[0], "http://specific:4318/custom/traces")
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}

///|
test "setup_trims_a_nonblank_endpoint" {
  @moonotel.shutdown_global_tracer_provider()
  @env.unset_env_var("OTEL_EXPORTER_OTLP_ENDPOINT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
  let capture = capturing_transport()
  let provider = @moonotel.setup(
    service_name="trimmed-endpoint",
    endpoint="  http://collector:4318  ",
    transport=capture.send(),
    use_batch=false,
  )
  let tracer = @moonotel.global_tracer("trimmed-endpoint")
  tracer.start_root_span("op").end()
  assert_eq(capture.urls.length(), 1)
  assert_eq(capture.urls[0], "http://collector:4318/v1/traces")
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}
