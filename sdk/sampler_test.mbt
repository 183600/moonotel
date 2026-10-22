// Blackbox tests for the built-in samplers.

///|
fn trace_id_starting_with(byte : Int32) -> Array[Int32] {
  let id : Array[Int32] = [byte]
  while id.length() < 16 {
    id.push(0)
  }
  id
}

///|
fn trace_id_ending_with(byte : Int32) -> Array[Int32] {
  let id : Array[Int32] = Array::make(15, 0)
  id.push(byte)
  id
}

///|
test "always_on" {
  let sampler = @sdk.Sampler::always_on()
  let decision = sampler.should_sample(None, trace_id_starting_with(0))
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

///|
test "always_off" {
  let sampler = @sdk.Sampler::always_off()
  let decision = sampler.should_sample(None, trace_id_starting_with(255))
  assert_false(decision.is_recorded)
  assert_false(decision.is_sampled)
}

///|
test "record_only" {
  let sampler = @sdk.Sampler::record_only()
  let decision = sampler.should_sample(None, trace_id_starting_with(1))
  assert_true(decision.is_recorded)
  assert_false(decision.is_sampled)
}

///|
test "ratio_zero_never_samples" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.0)
  let decision = sampler.should_sample(None, trace_id_ending_with(0))
  assert_false(decision.is_sampled)
}

///|
test "ratio_one_always_samples" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(1.0)
  let decision = sampler.should_sample(None, trace_id_ending_with(255))
  assert_true(decision.is_sampled)
}

///|
test "ratio_half_boundaries" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.5)
  let low = sampler.should_sample(None, trace_id_ending_with(0x00))
  let high_id : Array[Int32] = Array::make(16, 0)
  // The decision uses the most significant bit of the rightmost 8 bytes.
  high_id[8] = 0xFF
  let high = sampler.should_sample(None, high_id)
  assert_true(low.is_sampled)
  assert_false(high.is_sampled)
}

///|
test "ratio_out_of_range_is_clamped" {
  let negative = @sdk.Sampler::trace_id_ratio_based(-1.0)
  let large = @sdk.Sampler::trace_id_ratio_based(2.0)
  assert_false(
    negative.should_sample(None, trace_id_ending_with(1)).is_sampled,
  )
  assert_true(large.should_sample(None, trace_id_ending_with(1)).is_sampled)
}

///|
fn sampled_parent() -> @api.SpanContext {
  @api.span_context(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    [1, 2, 3, 4, 5, 6, 7, 8],
    1,
  )
}

///|
fn unsampled_parent() -> @api.SpanContext {
  @api.span_context(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    [1, 2, 3, 4, 5, 6, 7, 8],
    0,
  )
}

///|
test "parent_based_follows_sampled_parent" {
  let sampler = @sdk.Sampler::parent_based(@sdk.Sampler::always_off())
  let decision = sampler.should_sample(
    Some(sampled_parent()),
    trace_id_starting_with(1),
  )
  assert_true(decision.is_sampled)
}

///|
test "parent_based_follows_unsampled_parent" {
  let sampler = @sdk.Sampler::parent_based(@sdk.Sampler::always_on())
  let decision = sampler.should_sample(
    Some(unsampled_parent()),
    trace_id_starting_with(1),
  )
  assert_false(decision.is_sampled)
  assert_false(decision.is_recorded)
}

///|
test "parent_based_uses_root_without_parent" {
  let sampler = @sdk.Sampler::parent_based(@sdk.Sampler::always_off())
  let decision = sampler.should_sample(None, trace_id_starting_with(1))
  assert_false(decision.is_sampled)
}

///|
test "parent_based_uses_root_with_invalid_parent" {
  let sampler = @sdk.Sampler::parent_based(@sdk.Sampler::always_on())
  let decision = sampler.should_sample(
    Some(@api.invalid_span_context()),
    trace_id_starting_with(1),
  )
  assert_true(decision.is_sampled)
}
