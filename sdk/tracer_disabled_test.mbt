// Blackbox test for the no-op behavior of a provider built while
// `OTEL_SDK_DISABLED=true`.

///|
test "disabled_sdk_tracer_is_not_enabled_and_returns_noop_spans" {
  let previous = @env.get_env_var("OTEL_SDK_DISABLED")
  @env.set_env_var("OTEL_SDK_DISABLED", "true")
  let provider = @sdk.TracerProviderSdk::new(service_name="disabled")
  match previous {
    Some(value) => @env.set_env_var("OTEL_SDK_DISABLED", value)
    None => @env.unset_env_var("OTEL_SDK_DISABLED")
  }
  let tracer = provider.get_tracer("disabled")
  assert_false(tracer.enabled())
  let parent = @api.span_context(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    [1, 2, 3, 4, 5, 6, 7, 8],
    @api.TRACE_FLAGS_SAMPLED,
  )
  let span = tracer.start_span("disabled", parent~)
  assert_false(span.is_recording())
  assert_eq(span.context().trace_id_hex(), parent.trace_id_hex())
  assert_eq(span.context().span_id_hex(), parent.span_id_hex())
}
