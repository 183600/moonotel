// The ratio sampler must make the same decision for a SpanContext ID and its
// serialized byte form. Out-of-range array elements are serialized using their
// low nibble (the same normalization used by `bytes_to_hex`, the W3C
// propagator and the OTLP encoders), so the sampler must use that byte value
// rather than the low eight bits.

///|
test "ratio_sampler_uses_the_serialized_trace_id_bytes" {
  let out_of_range : Array[Int32] = Array::make(16, 0)
  out_of_range[15] = 0x1FF
  let serialized : Array[Int32] = Array::make(16, 0)
  serialized[15] = 0x0F
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.1)
  // The serialized ID ends with 0x0f and falls below the 10% threshold.
  assert_true(sampler.should_sample(None, serialized).is_sampled)
  // The raw `0x1ff` element must not be treated as the byte 0xff.
  assert_true(sampler.should_sample(None, out_of_range).is_sampled)
}

///|
test "ratio_sampler_normalizes_negative_trace_id_elements" {
  let out_of_range : Array[Int32] = Array::make(16, 0)
  out_of_range[15] = -1
  let serialized : Array[Int32] = Array::make(16, 0)
  serialized[15] = 0x0F
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.1)
  assert_eq(
    sampler.should_sample(None, out_of_range).is_sampled,
    sampler.should_sample(None, serialized).is_sampled,
  )
  assert_true(sampler.should_sample(None, out_of_range).is_sampled)
}
