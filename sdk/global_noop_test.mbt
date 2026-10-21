// The global TracerProvider must never be null: when none has been installed
// the global tracer comes from the no-op provider and creates non-recording
// spans instead of failing.

///|
test "global_tracer_without_a_provider_uses_the_no_op_provider" {
  @sdk.shutdown_global_tracer_provider()
  assert_true(@sdk.global_tracer_provider() is None)
  let tracer = @sdk.global_tracer("no-op-scope")
  assert_eq(tracer.scope_name(), "no-op-scope")
  assert_false(tracer.enabled())
  let span = tracer.start_root_span("dropped")
  assert_false(span.is_recording())
  assert_false(span.context().is_valid())
  span.end()
  @sdk.shutdown_global_tracer_provider()
}

///|
test "no_op_tracer_provider_is_disabled_and_does_not_export" {
  let provider = @sdk.no_op_tracer_provider()
  assert_true(provider.is_shutdown() == false)
  assert_eq(provider.processor_count(), 0)
  let tracer = provider.get_tracer("no-op-provider-scope")
  assert_false(tracer.enabled())
  let span = tracer.start_root_span("dropped")
  assert_false(span.is_recording())
  span.set_attribute("key", @sdk.StringValue("value"))
  span.end()
}

///|
test "global_tracer_provider_is_used_when_it_is_installed" {
  @sdk.shutdown_global_tracer_provider()
  let provider = @sdk.TracerProviderSdk::new(service_name="global-svc")
  @sdk.set_global_tracer_provider(provider)
  let tracer = @sdk.global_tracer("installed-scope")
  assert_eq(tracer.scope_name(), "installed-scope")
  @sdk.shutdown_global_tracer_provider()
}
