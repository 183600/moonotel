// Tests for the configurable ParentBased sampler delegates.

fn pbv_trace_id(byte : Int) -> Array[Int] {
  let id : Array[Int] = [byte]
  while id.length() < 16 {
    id.push(0)
  }
  id
}

fn pbv_parent(sampled : Bool, remote : Bool) -> @api.SpanContext {
  @api.span_context(
    Array::make(16, 3),
    Array::make(8, 4),
    if sampled { @api.TRACE_FLAGS_SAMPLED } else { 0 },
    is_remote=remote,
  )
}

fn pbv_clear_sampler_env() -> Unit {
  @env.unset_env_var("OTEL_TRACES_SAMPLER")
  @env.unset_env_var("OTEL_TRACES_SAMPLER_ARG")
  @env.unset_env_var("OTEL_SDK_DISABLED")
}

test "parent_based_remote_sampled_uses_the_remote_delegate" {
  let sampler = @sdk.Sampler::parent_based(
    @sdk.Sampler::always_off(),
    remote_parent_sampled=@sdk.Sampler::record_only(),
  )
  let decision = sampler.should_sample(Some(pbv_parent(true, true)), pbv_trace_id(1))
  assert_true(decision.is_recorded)
  assert_false(decision.is_sampled)
}

test "parent_based_remote_sampled_delegate_does_not_apply_locally" {
  let sampler = @sdk.Sampler::parent_based(
    @sdk.Sampler::always_off(),
    remote_parent_sampled=@sdk.Sampler::always_off(),
  )
  let decision = sampler.should_sample(Some(pbv_parent(true, false)), pbv_trace_id(1))
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

test "parent_based_local_not_sampled_delegate_only_applies_locally" {
  let sampler = @sdk.Sampler::parent_based(
    @sdk.Sampler::always_on(),
    local_parent_not_sampled=@sdk.Sampler::record_only(),
  )
  let local_decision = sampler.should_sample(Some(pbv_parent(false, false)), pbv_trace_id(1))
  assert_true(local_decision.is_recorded)
  assert_false(local_decision.is_sampled)
  let remote = sampler.should_sample(Some(pbv_parent(false, true)), pbv_trace_id(1))
  assert_false(remote.is_recorded)
  assert_false(remote.is_sampled)
}

test "parent_based_remote_not_sampled_delegate" {
  let sampler = @sdk.Sampler::parent_based(
    @sdk.Sampler::always_on(),
    remote_parent_not_sampled=@sdk.Sampler::record_only(),
  )
  let decision = sampler.should_sample(Some(pbv_parent(false, true)), pbv_trace_id(1))
  assert_true(decision.is_recorded)
  assert_false(decision.is_sampled)
}

test "parent_based_root_still_handles_missing_and_invalid_parents" {
  let sampler = @sdk.Sampler::parent_based(
    @sdk.Sampler::always_off(),
    remote_parent_sampled=@sdk.Sampler::record_only(),
    local_parent_sampled=@sdk.Sampler::record_only(),
    remote_parent_not_sampled=@sdk.Sampler::record_only(),
    local_parent_not_sampled=@sdk.Sampler::record_only(),
  )
  assert_false(sampler.should_sample(None, pbv_trace_id(1)).is_sampled)
  assert_false(
    sampler
    .should_sample(Some(@api.invalid_span_context()), pbv_trace_id(1))
    .is_sampled,
  )
}

test "sampler_from_env_parentbased_always_off" {
  pbv_clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "parentbased_always_off")
  let sampler = @sdk.Sampler::from_env()
  pbv_clear_sampler_env()
  assert_false(sampler.should_sample(None, pbv_trace_id(1)).is_sampled)
  assert_true(
    sampler.should_sample(Some(pbv_parent(true, false)), pbv_trace_id(1)).is_sampled,
  )
  assert_false(
    sampler
    .should_sample(Some(pbv_parent(false, false)), pbv_trace_id(1))
    .is_sampled,
  )
}

test "sampler_ratio_defaults_to_one_when_argument_is_absent" {
  pbv_clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "traceidratio")
  let sampler = @sdk.Sampler::from_env()
  pbv_clear_sampler_env()
  assert_true(sampler.should_sample(None, pbv_trace_id(255)).is_sampled)
}

test "sampler_ratio_nan_falls_back_to_one" {
  pbv_clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "traceidratio")
  @env.set_env_var("OTEL_TRACES_SAMPLER_ARG", "nan")
  let sampler = @sdk.Sampler::from_env()
  pbv_clear_sampler_env()
  assert_true(sampler.should_sample(None, pbv_trace_id(255)).is_sampled)
}

test "ratio_sampler_accepts_trace_ids_shorter_than_eight_bytes" {
  let sampler = @sdk.Sampler::trace_id_ratio_based(0.5)
  assert_true(sampler.should_sample(None, [0, 0, 0]).is_sampled)
  assert_false(@sdk.Sampler::trace_id_ratio_based(0.0).should_sample(None, [1]).is_sampled)
}
