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
test "root span sets the random flag for a random trace id" {
  let provider = @sdk.TracerProviderSdk::new(service_name="random-flag")
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("random-flag").start_root_span("root")
  assert_eq(
    span.context().trace_flags(),
    @api.TRACE_FLAGS_SAMPLED | @api.TRACE_FLAGS_RANDOM,
  )
}

///|
test "a_custom_id_generator_does_not_claim_randomness_by_default" {
  let counter : Ref[Int32] = Ref(0)
  let generator = @sdk.IdGenerator::new(fn() {
    counter.val = counter.val + 1
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap()
  }, fn() {
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap()
  })
  assert_false(generator.generates_random_trace_ids())
  let provider = @sdk.TracerProviderSdk::new(service_name="random-flag")
    .with_sampler(@sdk.Sampler::always_on())
    .with_id_generator(generator)
  let span = provider.get_tracer("random-flag").start_root_span("root")
  assert_eq(span.context().trace_flags(), @api.TRACE_FLAGS_SAMPLED)
}

///|
test "a_custom_id_generator_can_advertise_randomness" {
  let generator = @sdk.IdGenerator::new(fn() {
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap()
  }, fn() {
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap()
  }, trace_id_is_random=true)
  assert_true(generator.generates_random_trace_ids())
  let provider = @sdk.TracerProviderSdk::new(service_name="random-flag")
    .with_sampler(@sdk.Sampler::always_on())
    .with_id_generator(generator)
  let span = provider.get_tracer("random-flag").start_root_span("root")
  assert_eq(
    span.context().trace_flags(),
    @api.TRACE_FLAGS_SAMPLED | @api.TRACE_FLAGS_RANDOM,
  )
}

///|
test "root span with the deterministic generator only sets sampled" {
  let provider = @sdk.TracerProviderSdk::new(service_name="random-flag")
    .with_sampler(@sdk.Sampler::always_on())
    .with_id_generator(@sdk.IdGenerator::deterministic(7))
  let span = provider.get_tracer("random-flag").start_root_span("root")
  assert_eq(span.context().trace_flags(), @api.TRACE_FLAGS_SAMPLED)
}
