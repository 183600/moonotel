// The `sampler` argument of the facade `setup` must override the environment.

///|
test "setup_with_sampler_option_uses_it" {
  @otel.shutdown_global_tracer_provider()
  let provider = @otel.setup(
    service_name="sampler-facade",
    sampler=@otel.Sampler::always_off(),
  )
  let tracer = @otel.global_tracer("sampler-scope")
  let span = tracer.start_root_span("dropped")
  assert_false(span.is_recording())
  span.end()
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}
