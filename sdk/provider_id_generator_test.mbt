// The ID generator installed on the provider must drive the IDs of new spans.

///|
test "with_id_generator_is_used_by_the_tracer" {
  let provider = @sdk.TracerProviderSdk::new(service_name="ids").with_id_generator(
    @sdk.IdGenerator::deterministic(42),
  )
  let tracer = provider.get_tracer("ids")
  let span = tracer.start_root_span("op")
  let expected = @sdk.IdGenerator::deterministic(42)
  assert_eq(
    @api.bytes_to_hex(span.context().trace_id()),
    @api.bytes_to_hex(expected.generate_trace_id()),
  )
  assert_eq(
    @api.bytes_to_hex(span.context().span_id()),
    @api.bytes_to_hex(expected.generate_span_id()),
  )
  span.end()
}
