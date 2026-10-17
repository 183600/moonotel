// Blackbox tests for the exact boundaries of `Sampler::trace_id_ratio_based`.
//
// The sampler follows the cross-language TraceIdRatioBased algorithm: the
// leading 64 bits of the trace ID are shifted right by one and compared with
// `ratio * 2^63`. These tests pin down the exact cut-over point so the
// behavior stays identical to the OpenTelemetry SDKs in other languages.

fn ratio_trace_id(high64 : UInt64) -> Array[Int] {
  let id : Array[Int] = []
  let mut i = 0
  while i < 8 {
    id.push(((high64 >> (56 - i * 8)) & 0xFF).to_int())
    i = i + 1
  }
  while id.length() < 16 {
    id.push(0)
  }
  id
}

test "ratio_half_boundary_uses_top_bit" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.5)
  assert_true(
    sampler.should_sample(None, ratio_trace_id(0x7FFFFFFFFFFFFFFF)).is_sampled,
  )
  assert_false(
    sampler.should_sample(None, ratio_trace_id(0x8000000000000000)).is_sampled,
  )
}

test "ratio_quarter_boundary" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.25)
  assert_true(
    sampler.should_sample(None, ratio_trace_id(0x3FFFFFFFFFFFFFFF)).is_sampled,
  )
  assert_false(
    sampler.should_sample(None, ratio_trace_id(0x4000000000000000)).is_sampled,
  )
}

test "ratio_three_quarters_boundary" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.75)
  assert_true(
    sampler.should_sample(None, ratio_trace_id(0xBFFFFFFFFFFFFFFF)).is_sampled,
  )
  assert_false(
    sampler.should_sample(None, ratio_trace_id(0xC000000000000000)).is_sampled,
  )
}

test "ratio_boundary_ignores_low_bits" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.5)
  assert_true(
    sampler.should_sample(None, ratio_trace_id(0x7FFFFFFF00000000)).is_sampled,
  )
  assert_false(
    sampler.should_sample(None, ratio_trace_id(0x80000000FFFFFFFF)).is_sampled,
  )
}

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
