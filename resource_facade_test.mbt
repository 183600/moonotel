// Facade tests for the re-exported `Resource` type and for
// `OTEL_TRACES_EXPORTER=none` on the automatic `setup`.

///|
test "facade_resource_flows_into_the_provider" {
  @env.unset_env_var("OTEL_SERVICE_NAME")
  @env.unset_env_var("OTEL_RESOURCE_ATTRIBUTES")
  let resource = @otel.Resource::from_env(service_name="facade-resource").with_attribute(
    "deployment.environment",
    @sdk.StringValue("test"),
  )
  let provider = @otel.TracerProviderSdk::new().with_resource(resource)
  assert_eq(
    provider.resource().get("deployment.environment"),
    Some(@sdk.StringValue("test")),
  )
  assert_eq(
    provider.resource().get(@sdk.SERVICE_NAME),
    Some(@sdk.StringValue("facade-resource")),
  )
  provider.shutdown()
}

///|
test "setup_respects_traces_exporter_none" {
  @otel.shutdown_global_tracer_provider()
  @env.set_env_var("OTEL_TRACES_EXPORTER", "none")
  let capture = capturing_transport()
  let provider = @otel.setup(
    service_name="disabled-exporter",
    transport=capture.send(),
    use_batch=false,
  )
  let tracer = @otel.global_tracer("disabled-scope")
  let span = tracer.start_root_span("recorded-but-not-exported")
  assert_true(span.is_recording())
  span.end()
  assert_eq(capture.urls.length(), 0)
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}

///|
test "setup_accepts_a_prebuilt_resource" {
  @otel.shutdown_global_tracer_provider()
  @env.unset_env_var("OTEL_SERVICE_NAME")
  @env.unset_env_var("OTEL_RESOURCE_ATTRIBUTES")
  let resource = @otel.Resource::new(
    attributes=Map([
      (@sdk.SERVICE_NAME, @sdk.StringValue("setup-resource")),
      ("deployment.environment", @sdk.StringValue("staging")),
    ]),
  )
  let capture = capturing_transport()
  let provider = @otel.setup(
    resource~,
    resource_attributes=Map([
      ("deployment.environment", @sdk.StringValue("production")),
    ]),
    transport=capture.send(),
    use_batch=false,
  )
  assert_eq(
    provider.resource().get(@sdk.SERVICE_NAME),
    Some(@sdk.StringValue("setup-resource")),
  )
  assert_eq(
    provider.resource().get("deployment.environment"),
    Some(@sdk.StringValue("production")),
  )
  let tracer = provider.get_tracer("resource-scope")
  let span = tracer.start_root_span("op")
  span.end()
  assert_eq(capture.urls.length(), 1)
  assert_true(capture.bodies[0].length() > 0)
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}
