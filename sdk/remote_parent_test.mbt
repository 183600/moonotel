// The `is_remote` flag must not leak into locally created child spans.

fn remote_parent_context() -> @context.Context {
  let parent = @api.span_context(
    Array::make(16, 1),
    Array::make(8, 2),
    @api.TRACE_FLAGS_SAMPLED,
    tracestate="vendor=value",
    is_remote=true,
  )
  @context.Context::root().with_span(parent)
}

test "child of a remote parent is local" {
  let provider = @sdk.TracerProviderSdk::new()
  let tracer = provider.get_tracer("remote-parent")
  let span = tracer.start_span_with_context(
    "child",
    context=remote_parent_context(),
  )
  assert_false(span.context().is_remote())
  assert_true(span.context().is_valid())
}

test "child of a remote parent keeps its tracestate" {
  let provider = @sdk.TracerProviderSdk::new()
  let tracer = provider.get_tracer("remote-parent")
  let span = tracer.start_span_with_context(
    "child",
    context=remote_parent_context(),
  )
  assert_false(span.context().is_remote())
  assert_eq(span.context().tracestate(), "vendor=value")
  assert_eq(span.context().trace_id(), Array::make(16, 1))
}
