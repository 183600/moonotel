// The W3C random-trace-id flag belongs to the trace ID and must survive span
// continuation, while reserved flag bits are never copied.

///|
test "child span preserves the parent random trace flag" {
  let parent = @api.span_context(
    Array::make(16, 7),
    Array::make(8, 8),
    @api.TRACE_FLAGS_SAMPLED |
    @api.TRACE_FLAGS_RANDOM |
    0x04,
    is_remote=true,
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="random-flag")
    .with_sampler(@sdk.Sampler::always_on())
  let child = provider.get_tracer("random-flag").start_span("child", parent~)
  assert_eq(
    child.context().trace_flags(),
    @api.TRACE_FLAGS_SAMPLED | @api.TRACE_FLAGS_RANDOM,
  )
  assert_true(child.context().is_sampled())
}

///|
test "root span keeps the sampler-only trace flags" {
  let provider = @sdk.TracerProviderSdk::new(service_name="random-flag")
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("random-flag").start_root_span("root")
  assert_eq(span.context().trace_flags(), @api.TRACE_FLAGS_SAMPLED)
}
