// A custom sampler receives the parent SpanContext, whose public ID views
// alias the backing arrays. Mutating those views must not change the parent
// context or the identifiers of the child span that is being started.

///|
test "sampler cannot mutate the parent context used for the child span" {
  let parent = @api.span_context(
    Array::make(16, 7),
    Array::make(8, 9),
    @api.TRACE_FLAGS_SAMPLED,
    is_remote=true,
  )
  let expected_trace = parent.trace_id_hex()
  let expected_parent_span = parent.span_id_hex()
  let sampler = @sdk.Sampler::new("ParentMutatingSampler", fn(parameters) {
    match parameters.parent {
      Some(ctx) => {
        let trace_id = ctx.trace_id_view()
        for i = 0; i < trace_id.length(); i = i + 1 {
          trace_id[i] = 0
        }
        let span_id = ctx.span_id_view()
        for i = 0; i < span_id.length(); i = i + 1 {
          span_id[i] = 0
        }
      }
      None => ()
    }
    @sdk.sampling_decision_record_and_sample()
  })
  let provider = @sdk.TracerProviderSdk::new(service_name="parent-isolation").with_sampler(
    sampler,
  )
  let child = provider
    .get_tracer("parent-isolation")
    .start_span("child", parent~)
  assert_eq(child.context().trace_id_hex(), expected_trace)
  assert_eq(@api.bytes_to_hex(child.parent_span_id()), expected_parent_span)
  assert_eq(parent.trace_id_hex(), expected_trace)
  assert_eq(parent.span_id_hex(), expected_parent_span)
  child.end()
}
