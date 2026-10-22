// The sampled flag of a new span's context must follow the sampling
// decision: only RECORD_AND_SAMPLE sets it.

///|
test "drop_decision_never_sets_the_sampled_flag" {
  let provider = @sdk.TracerProviderSdk::new(service_name="flag-probe")
    .with_sampler(
      @sdk.Sampler::new("IllegalSampledWithoutRecord", fn(_parameters) {
        { is_recorded: false, is_sampled: true, }
      }),
    )
  let span = provider.get_tracer("flag-probe").start_root_span("span")
  assert_false(span.is_recording())
  assert_false(span.context().is_sampled())
  // The random-trace-id flag still describes the generated trace ID, but the
  // sampled bit must never be set without a recording decision.
  assert_eq(span.context().trace_flags(), @api.TRACE_FLAGS_RANDOM)
}

///|
test "record_and_sample_decision_sets_the_sampled_flag" {
  let provider = @sdk.TracerProviderSdk::new(service_name="flag-probe")
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("flag-probe").start_root_span("span")
  assert_true(span.is_recording())
  assert_true(span.context().is_sampled())
  assert_eq(
    span.context().trace_flags(),
    @api.TRACE_FLAGS_SAMPLED | @api.TRACE_FLAGS_RANDOM,
  )
}
