// Blackbox tests for sampler descriptions and NaN ratio handling.

///|
test "sampler_descriptions_follow_spec_format" {
  assert_eq(@sdk.Sampler::always_on().description(), "AlwaysOnSampler")
  assert_eq(@sdk.Sampler::always_off().description(), "AlwaysOffSampler")
  assert_eq(
    @sdk.Sampler::trace_id_ratio_based(0.25).description(),
    "TraceIdRatioBased{0.25}",
  )
}

///|
test "ratio_sampler_description_keeps_configured_ratio" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.125)
  assert_true(sampler.description().contains("TraceIdRatioBased{"))
  assert_true(sampler.description().contains("0.125"))
}

///|
test "parent_based_description_mentions_root_sampler" {
  let sampler = @sdk.Sampler::parent_based(@sdk.Sampler::always_off())
  assert_eq(sampler.description(), "ParentBased{AlwaysOffSampler}")
}

///|
test "ratio_sampler_keeps_identity_at_boundaries" {
  assert_true(
    @sdk.Sampler::trace_id_ratio_based(0.0)
    .description()
    .contains("TraceIdRatioBased"),
  )
  assert_true(
    @sdk.Sampler::trace_id_ratio_based(1.0)
    .description()
    .contains("TraceIdRatioBased"),
  )
}

///|
test "ratio_nan_behaves_like_always_on" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.0 / 0.0)
  let decision = sampler.should_sample(
    None,
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  )
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

///|
test "ratio_infinity_is_clamped" {
  let positive = @sdk.Sampler::trace_id_ratio_based(1.0 / 0.0)
  let negative = @sdk.Sampler::trace_id_ratio_based(-1.0 / 0.0)
  assert_true(
    positive
    .should_sample(None, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255])
    .is_sampled,
  )
  assert_false(
    negative
    .should_sample(None, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    .is_sampled,
  )
}
