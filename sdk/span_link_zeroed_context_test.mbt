// A link whose live SpanContext IDs were zeroed after construction is an
// invalid link and must be dropped unless it carries attributes or tracestate,
// matching the rule for any other invalid link.

///|
fn zeroed_link_context() -> @api.SpanContext {
  let context = @api.span_context(
    Array::make(16, 1),
    Array::make(8, 2),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let trace = context.trace_id_view()
  for i = 0; i < trace.length(); i = i + 1 {
    trace[i] = 0
  }
  context
}

///|
test "link_with_zeroed_live_ids_is_dropped" {
  let provider = @sdk.TracerProviderSdk::new(service_name="zeroed-link")
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("zeroed-link").start_root_span("op")
  span.add_link(@sdk.SpanLink::new(zeroed_link_context()))
  assert_eq(span.links().length(), 0)
}

///|
test "link_with_zeroed_live_ids_and_attributes_is_kept" {
  let provider = @sdk.TracerProviderSdk::new(service_name="zeroed-link")
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("zeroed-link").start_root_span("op")
  span.add_link(
    @sdk.SpanLink::new(
      zeroed_link_context(),
      attributes=Map([("reason", @sdk.StringValue("invalid-context"))]),
    ),
  )
  let links = span.links()
  assert_eq(links.length(), 1)
  assert_eq(
    links[0].attributes.get("reason"),
    Some(@sdk.StringValue("invalid-context")),
  )
}
