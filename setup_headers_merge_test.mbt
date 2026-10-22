// `setup` layers explicitly supplied headers over the standard OTLP header
// environment variables instead of replacing the whole environment map. An
// override must win case-insensitively while unrelated environment headers
// (including signal-specific ones) are still sent.

///|
test "setup_merges_programmatic_headers_with_environment_headers" {
  @moonotel.shutdown_global_tracer_provider()
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_HEADERS",
    "env-only=1,shared=environment",
  )
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_TRACES_HEADERS",
    "signal-only=2,shared=signal",
  )
  let capture = capturing_transport()
  let provider = @moonotel.setup(
    service_name="header-merge-facade",
    endpoint="http://collector:4318",
    transport=capture.send(),
    headers=Map([
      ("Shared", "programmatic"),
      ("programmatic", "3"),
    ]),
    use_batch=false,
  )
  let tracer = provider.get_tracer("header-merge-scope")
  tracer.start_root_span("op").end()
  assert_eq(capture.urls.length(), 1)
  let headers = capture.headers[0]
  assert_eq(headers.get("env-only"), Some("1"))
  assert_eq(headers.get("signal-only"), Some("2"))
  assert_eq(headers.get("Shared"), Some("programmatic"))
  assert_eq(headers.get("shared"), None)
  assert_eq(headers.get("programmatic"), Some("3"))
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
  @env.unset_env_var("OTEL_EXPORTER_OTLP_HEADERS")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_HEADERS")
}
