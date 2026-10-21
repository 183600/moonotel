// Smoke tests for the re-exported span link surface.

///|
test "facade_exposes_span_links" {
  let link_context = @moonotel.span_context(
    @moonotel.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @moonotel.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    @moonotel.TRACE_FLAGS_SAMPLED,
  )
  let link = @moonotel.SpanLink::new(link_context)
  assert_true(link.span_context.is_valid())
  assert_true(link.span_context.is_sampled())
  assert_eq(link.attributes.length(), 0)
}

///|
test "facade_start_span_accepts_links" {
  @moonotel.shutdown_global_tracer_provider()
  let provider = @moonotel.setup(service_name="facade-links")
  let tracer = @moonotel.global_tracer("facade-links")
  let link = @moonotel.SpanLink::new(
    @moonotel.span_context(
      @moonotel.bytes_from_hex("0af7651916cd43dd8448eb211c80319c").unwrap(),
      @moonotel.bytes_from_hex("b7ad6b7169203331").unwrap(),
      1,
    ),
  )
  let span = tracer.start_root_span("op", links=[link])
  assert_eq(span.links().length(), 1)
  span.end()
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}
