// Tests that a span and its links own their SpanContexts rather than aliasing
// caller-held ID arrays.

///|
fn isolation_context(trace_byte : Int32, span_byte : Int32) -> @api.SpanContext {
  @api.span_context(Array::make(16, trace_byte), Array::make(8, span_byte), 1)
}

///|
test "span_context_accessor_returns_an_independent_copy" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="isolation")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("isolation").start_root_span("op")
  let trace_hex = span.context().trace_id_hex()
  let span_hex = span.context().span_id_hex()
  let context = span.context()
  context.trace_id_view()[0] = 99
  context.span_id_view()[0] = 99
  assert_eq(span.context().trace_id_hex(), trace_hex)
  assert_eq(span.context().span_id_hex(), span_hex)
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.span_context.trace_id_hex(), trace_hex)
  assert_eq(data.span_context.span_id_hex(), span_hex)
}

///|
test "child_span_does_not_alias_parent_context_ids" {
  let provider = @sdk.TracerProviderSdk::new(service_name="isolation")
    .with_sampler(@sdk.Sampler::always_on())
  let parent = isolation_context(1, 2)
  let parent_trace = parent.trace_id_hex()
  let parent_span = parent.span_id_hex()
  let child = provider.get_tracer("isolation").start_span("child", parent~)
  parent.trace_id_view()[0] = 99
  parent.span_id_view()[0] = 99
  assert_eq(child.context().trace_id_hex(), parent_trace)
  assert_eq(@api.bytes_to_hex(child.parent_span_id()), parent_span)
}

///|
test "add_link_copies_the_link_span_context" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="isolation")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("isolation").start_root_span("op")
  let link_context = isolation_context(3, 4)
  let trace_hex = link_context.trace_id_hex()
  let span_hex = link_context.span_id_hex()
  span.add_link(@sdk.SpanLink::new(link_context))
  link_context.trace_id_view()[0] = 99
  link_context.span_id_view()[0] = 99
  assert_eq(span.links()[0].span_context.trace_id_hex(), trace_hex)
  assert_eq(span.links()[0].span_context.span_id_hex(), span_hex)
  span.end()
  let link = exporter.exported_spans()[0].links[0]
  assert_eq(link.span_context.trace_id_hex(), trace_hex)
  assert_eq(link.span_context.span_id_hex(), span_hex)
}

///|
test "start_span_links_are_isolated_from_caller_contexts" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="isolation")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let link_context = isolation_context(5, 6)
  let trace_hex = link_context.trace_id_hex()
  let span_hex = link_context.span_id_hex()
  let span = provider.get_tracer("isolation").start_span(
    "op",
    links=[@sdk.SpanLink::new(link_context)],
  )
  link_context.trace_id_view()[0] = 99
  link_context.span_id_view()[0] = 99
  span.end()
  let link = exporter.exported_spans()[0].links[0]
  assert_eq(link.span_context.trace_id_hex(), trace_hex)
  assert_eq(link.span_context.span_id_hex(), span_hex)
}

///|
test "derived_span_contexts_do_not_alias_the_original_ids" {
  let context = isolation_context(7, 8)
  let trace_hex = context.trace_id_hex()
  let span_hex = context.span_id_hex()
  let with_state = context.with_tracestate("vendor=value")
  let remote = context.with_remote(true)
  with_state.trace_id_view()[0] = 99
  with_state.span_id_view()[0] = 99
  remote.trace_id_view()[0] = 99
  remote.span_id_view()[0] = 99
  assert_eq(context.trace_id_hex(), trace_hex)
  assert_eq(context.span_id_hex(), span_hex)
}

///|
test "exported_span_context_does_not_alias_the_ended_span" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="isolation")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("isolation").start_root_span("op")
  let trace_hex = span.context().trace_id_hex()
  let span_hex = span.context().span_id_hex()
  span.end()
  let data = exporter.exported_spans()[0]
  data.span_context.trace_id_view()[0] = 99
  data.span_context.span_id_view()[0] = 99
  assert_eq(span.context().trace_id_hex(), trace_hex)
  assert_eq(span.context().span_id_hex(), span_hex)
}
