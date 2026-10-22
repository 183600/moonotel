// A parent SpanContext whose live IDs were zeroed after construction must no
// longer be used as a parent: the child would otherwise carry an invalid trace
// ID and an all-zero parent span ID into the exporter.

///|
fn live_parent_context() -> @api.SpanContext {
  @api.span_context(
    Array::make(16, 7),
    Array::make(8, 9),
    @api.TRACE_FLAGS_SAMPLED,
  )
}

///|
fn all_zero(bytes : Array[Int32]) -> Bool {
  for value in bytes {
    if value != 0 {
      return false
    }
  }
  true
}

///|
test "zeroed_parent_trace_id_starts_a_new_root_trace" {
  let provider = @sdk.TracerProviderSdk::new(service_name="live-parent")
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("live-parent")
  let parent = live_parent_context()
  let trace = parent.trace_id_view()
  for i = 0; i < trace.length(); i = i + 1 {
    trace[i] = 0
  }
  let child = tracer.start_span("child", parent~)
  assert_true(child.context().is_valid())
  assert_false(all_zero(child.context().trace_id()))
  assert_eq(child.parent_span_id().length(), 0)
}

///|
test "zeroed_parent_span_id_starts_a_new_root_trace" {
  let provider = @sdk.TracerProviderSdk::new(service_name="live-parent")
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("live-parent")
  let parent = live_parent_context()
  let span = parent.span_id_view()
  for i = 0; i < span.length(); i = i + 1 {
    span[i] = 0
  }
  let child = tracer.start_span("child", parent~)
  assert_true(child.context().is_valid())
  assert_false(all_zero(child.context().trace_id()))
  assert_eq(child.parent_span_id().length(), 0)
}

///|
test "parent_based_sampler_ignores_zeroed_live_parent_ids" {
  let parent = live_parent_context()
  let trace = parent.trace_id_view()
  for i = 0; i < trace.length(); i = i + 1 {
    trace[i] = 0
  }
  let sampler = @sdk.Sampler::parent_based(@sdk.Sampler::always_off())
  let decision = sampler.should_sample(Some(parent), Array::make(16, 3))
  assert_false(decision.is_recorded)
  assert_false(decision.is_sampled)
}
