// `setup` must not build processors or exporters when `OTEL_SDK_DISABLED=true`:
// the provider never records a span, so an exporter could only waste resources
// (or start background work that is immediately shut down).

///|
test "setup_with_sdk_disabled_installs_no_processor_or_exporter" {
  let previous = @env.get_env_var("OTEL_SDK_DISABLED")
  defer (match previous {
    Some(value) => @env.set_env_var("OTEL_SDK_DISABLED", value)
    None => @env.unset_env_var("OTEL_SDK_DISABLED")
  })
  @env.set_env_var("OTEL_SDK_DISABLED", "true")
  @moonotel.shutdown_global_tracer_provider()
  let capture = capturing_transport()
  let provider = @moonotel.setup(
    service_name="disabled-sdk-facade",
    endpoint="http://collector:4318",
    transport=capture.send(),
    exporters=["otlp", "console"],
    use_batch=false,
  )
  assert_true(provider.is_disabled())
  assert_eq(provider.processor_count(), 0)
  let tracer = @moonotel.global_tracer("disabled-sdk-scope")
  assert_false(tracer.enabled())
  let span = tracer.start_root_span("dropped")
  assert_false(span.is_recording())
  span.end()
  assert_eq(capture.urls.length(), 0)
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}
