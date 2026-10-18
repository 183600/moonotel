// Exhausting the buffered entropy draw must transparently refill it.

///|
test "random_generator_refills_after_exhausting_the_buffered_draw" {
  let generator = @sdk.IdGenerator::random()
  // The internal draw holds a whole number of trace IDs, so more than a
  // hundred consecutive draws cross at least one buffer boundary.
  for i = 0; i < 130; i = i + 1 {
    let trace_id = generator.generate_trace_id()
    let span_id = generator.generate_span_id()
    assert_eq(trace_id.length(), 16)
    assert_eq(span_id.length(), 8)
    assert_false(@api.is_zero(trace_id))
    assert_false(@api.is_zero(span_id))
  }
}
