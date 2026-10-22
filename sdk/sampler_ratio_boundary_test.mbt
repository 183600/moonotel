// Blackbox tests for the exact boundaries of `Sampler::trace_id_ratio_based`.
//
// The sampler follows the cross-language TraceIdRatioBased algorithm: the
// rightmost 8 bytes of the trace ID are shifted right by one and compared with
// `ratio * 2^63`. These tests pin down the exact cut-over point so the behavior
// stays aligned with the OpenTelemetry SDKs in other languages.

///|
fn ratio_trace_id(low64 : UInt64) -> Array[Int32] {
  let id : Array[Int32] = Array::make(8, 0)
  let mut i = 0
  while i < 8 {
    id.push(((low64 >> (56 - i * 8)) & 0xFF).to_int())
    i = i + 1
  }
  id
}

///|
test "ratio_half_boundary_uses_top_bit_of_the_rightmost_bytes" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.5)
  assert_true(
    sampler.should_sample(None, ratio_trace_id(0x7FFFFFFFFFFFFFFF)).is_sampled,
  )
  assert_false(
    sampler.should_sample(None, ratio_trace_id(0x8000000000000000)).is_sampled,
  )
}

///|
test "ratio_quarter_boundary" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.25)
  assert_true(
    sampler.should_sample(None, ratio_trace_id(0x3FFFFFFFFFFFFFFF)).is_sampled,
  )
  assert_false(
    sampler.should_sample(None, ratio_trace_id(0x4000000000000000)).is_sampled,
  )
}

///|
test "ratio_three_quarters_boundary" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.75)
  assert_true(
    sampler.should_sample(None, ratio_trace_id(0xBFFFFFFFFFFFFFFF)).is_sampled,
  )
  assert_false(
    sampler.should_sample(None, ratio_trace_id(0xC000000000000000)).is_sampled,
  )
}

///|
test "ratio_boundary_ignores_low_bits_of_the_rightmost_word" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.5)
  assert_true(
    sampler.should_sample(None, ratio_trace_id(0x7FFFFFFF00000000)).is_sampled,
  )
  assert_false(
    sampler.should_sample(None, ratio_trace_id(0x80000000FFFFFFFF)).is_sampled,
  )
}

///|
test "ratio_ignores_the_leading_bytes" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.5)
  let low = ratio_trace_id(0x0000000000000001)
  let high_prefix = ratio_trace_id(0x0000000000000001)
  for i = 0; i < 8; i = i + 1 {
    high_prefix[i] = 0xFF
  }
  assert_eq(
    sampler.should_sample(None, low).is_sampled,
    sampler.should_sample(None, high_prefix).is_sampled,
  )
  assert_true(sampler.should_sample(None, low).is_sampled)
}

///|
test "ratio_small_is_deterministic" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.001)
  let id = ratio_trace_id(0x0000000000000001)
  assert_eq(
    sampler.should_sample(None, id).is_sampled,
    sampler.should_sample(None, id).is_sampled,
  )
  assert_false(
    sampler.should_sample(None, ratio_trace_id(0xFFFFFFFFFFFFFFFF)).is_sampled,
  )
}

///|
test "ratio_sampler_pads_short_trace_ids_on_the_left" {
  // A short trace ID uses its bytes as the rightmost bytes of the suffix; the
  // missing leading bytes are zero, exactly like the equivalent padded ID.
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.5)
  assert_true(sampler.should_sample(None, [0x80]).is_sampled)
  let one_percent = @sdk.Sampler::trace_id_ratio_based(0.01)
  assert_true(one_percent.should_sample(None, [0x01]).is_sampled)
  assert_true(one_percent.should_sample(None, [0x80]).is_sampled)
  assert_false(
    one_percent.should_sample(
      None,
      ratio_trace_id(0x8000000000000000),
    ).is_sampled,
  )
  let suffixes : Array[Array[Int32]] = [
    [], [0x00], [0x01], [0x7F], [0x80], [0xFF], [0x01, 0x02, 0x03],
    [0x80, 0x00, 0x00, 0x01], [0xFF, 0xFF, 0xFF, 0xFF, 0xFF],
    [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80],
  ]
  for suffix in suffixes {
    let padded : Array[Int32] = Array::make(16, 0)
    for i, byte in suffix {
      padded[16 - suffix.length() + i] = byte
    }
    assert_eq(
      sampler.should_sample(None, suffix).is_sampled,
      sampler.should_sample(None, padded).is_sampled,
    )
    assert_eq(
      one_percent.should_sample(None, suffix).is_sampled,
      one_percent.should_sample(None, padded).is_sampled,
    )
  }
}
