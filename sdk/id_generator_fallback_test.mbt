// A custom IdGenerator that returns an unusable ID must not create an invalid
// SpanContext or silently make the span unexportable. The SDK falls back to
// its random generator for the malformed ID.

///|
fn fallback_all_zero(bytes : Array[Int32]) -> Bool {
  for value in bytes {
    if value != 0 {
      return false
    }
  }
  true
}

///|
test "invalid custom trace id falls back to a valid random id" {
  let generator = @sdk.IdGenerator::new(
    fn() { Array::make(16, 0) },
    fn() { @api.bytes_from_hex("00f067aa0ba902b7").unwrap() },
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="fallback")
    .with_sampler(@sdk.Sampler::always_on())
    .with_id_generator(generator)
  let span = provider.get_tracer("fallback").start_root_span("op")
  let context = span.context()
  assert_true(context.is_valid())
  assert_eq(context.trace_id().length(), 16)
  assert_false(fallback_all_zero(context.trace_id()))
  // The fallback generator is random, so the W3C random flag is set even
  // though the custom generator did not advertise randomness.
  assert_eq(
    context.trace_flags() & @api.TRACE_FLAGS_RANDOM,
    @api.TRACE_FLAGS_RANDOM,
  )
  // The custom span ID was usable, so it is preserved.
  assert_eq(@api.bytes_to_hex(context.span_id()), "00f067aa0ba902b7")
  span.end()
}

///|
test "invalid custom span id falls back to a valid random id" {
  let generator = @sdk.IdGenerator::new(
    fn() { @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap() },
    fn() { Array::make(8, 0) },
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="fallback")
    .with_sampler(@sdk.Sampler::always_on())
    .with_id_generator(generator)
  let span = provider.get_tracer("fallback").start_root_span("op")
  let context = span.context()
  assert_true(context.is_valid())
  assert_eq(
    @api.bytes_to_hex(context.trace_id()),
    "4bf92f359d1e75b7618a2d1f3c4e5a6b",
  )
  assert_eq(context.span_id().length(), 8)
  assert_false(fallback_all_zero(context.span_id()))
  // The custom trace ID was usable and the generator did not opt into the
  // random flag, so only the sampled flag is set.
  assert_eq(
    context.trace_flags() & @api.TRACE_FLAGS_RANDOM,
    0,
  )
  span.end()
}

///|
test "malformed custom id lengths fall back to valid random ids" {
  let generator = @sdk.IdGenerator::new(
    fn() { Array::make(15, 7) },
    fn() { Array::make(7, 9) },
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="fallback")
    .with_sampler(@sdk.Sampler::always_on())
    .with_id_generator(generator)
  let span = provider.get_tracer("fallback").start_root_span("op")
  let context = span.context()
  assert_true(context.is_valid())
  assert_eq(context.trace_id().length(), 16)
  assert_eq(context.span_id().length(), 8)
  assert_false(fallback_all_zero(context.trace_id()))
  assert_false(fallback_all_zero(context.span_id()))
  span.end()
}

///|
test "custom ids that serialize to zero fall back to valid random ids" {
  let generator = @sdk.IdGenerator::new(
    fn() { Array::make(16, 256) },
    fn() { Array::make(8, 256) },
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="fallback")
    .with_sampler(@sdk.Sampler::always_on())
    .with_id_generator(generator)
  let span = provider.get_tracer("fallback").start_root_span("op")
  let context = span.context()
  assert_true(context.is_valid())
  assert_false(fallback_all_zero(context.trace_id()))
  assert_false(fallback_all_zero(context.span_id()))
  span.end()
}
