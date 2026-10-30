// Exhausting the buffered entropy draw must transparently refill it.

///|
test "random_generator_refills_after_exhausting_the_buffered_draw" {
  let generator = @sdk.IdGenerator::random()
  // Every iteration consumes 24 bytes (a 16-byte trace ID plus an 8-byte span
  // ID) from the 8192-byte buffered draw, so 400 iterations cross at least one
  // buffer boundary. Distinct values also prove that refilling does not reset
  // the buffer offset or reuse earlier bytes.
  let seen : Map[String, Bool] = Map([])
  for i = 0; i < 400; i = i + 1 {
    let trace_id = generator.generate_trace_id()
    let span_id = generator.generate_span_id()
    assert_eq(trace_id.length(), 16)
    assert_eq(span_id.length(), 8)
    assert_false(@api.is_zero(trace_id))
    assert_false(@api.is_zero(span_id))
    let trace_key = "t:" + @api.bytes_to_hex(trace_id)
    let span_key = "s:" + @api.bytes_to_hex(span_id)
    assert_false(seen.contains(trace_key))
    assert_false(seen.contains(span_key))
    seen.set(trace_key, true)
    seen.set(span_key, true)
  }
}
