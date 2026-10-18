// Tests for the standard sampler and kill-switch environment variables:
// OTEL_TRACES_SAMPLER, OTEL_TRACES_SAMPLER_ARG and OTEL_SDK_DISABLED.

fn clear_sampler_env() -> Unit {
  @env.unset_env_var("OTEL_TRACES_SAMPLER")
  @env.unset_env_var("OTEL_TRACES_SAMPLER_ARG")
  @env.unset_env_var("OTEL_SDK_DISABLED")
}

fn env_trace_id(byte : Int) -> Array[Int] {
  let id : Array[Int] = [byte]
  while id.length() < 16 {
    id.push(0)
  }
  id
}

test "sampler_from_env_defaults_to_parent_based_always_on" {
  clear_sampler_env()
  let sampler = @sdk.Sampler::from_env()
  let decision = sampler.should_sample(None, env_trace_id(255))
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
  clear_sampler_env()
}

test "sampler_from_env_reads_always_on_and_always_off" {
  clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "always_off")
  let off = @sdk.Sampler::from_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "always_on")
  let on = @sdk.Sampler::from_env()
  clear_sampler_env()
  assert_false(off.should_sample(None, env_trace_id(1)).is_sampled)
  assert_true(on.should_sample(None, env_trace_id(1)).is_sampled)
}

test "sampler_from_env_reads_traceidratio_argument" {
  clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "traceidratio")
  @env.set_env_var("OTEL_TRACES_SAMPLER_ARG", "0.0")
  let never = @sdk.Sampler::from_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER_ARG", "1.0")
  let always = @sdk.Sampler::from_env()
  clear_sampler_env()
  assert_false(never.should_sample(None, env_trace_id(0)).is_sampled)
  assert_true(always.should_sample(None, env_trace_id(255)).is_sampled)
}

test "sampler_from_env_invalid_ratio_falls_back_to_one" {
  clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "traceidratio")
  @env.set_env_var("OTEL_TRACES_SAMPLER_ARG", "not-a-number")
  let sampler = @sdk.Sampler::from_env()
  clear_sampler_env()
  assert_true(sampler.should_sample(None, env_trace_id(255)).is_sampled)
}

test "sampler_from_env_ratio_out_of_range_falls_back_to_one" {
  clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "traceidratio")
  @env.set_env_var("OTEL_TRACES_SAMPLER_ARG", "-0.5")
  let negative = @sdk.Sampler::from_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER_ARG", "1.5")
  let large = @sdk.Sampler::from_env()
  clear_sampler_env()
  assert_true(negative.should_sample(None, env_trace_id(255)).is_sampled)
  assert_true(large.should_sample(None, env_trace_id(255)).is_sampled)
}

test "sampler_from_env_argument_ignored_for_other_samplers" {
  clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "always_on")
  @env.set_env_var("OTEL_TRACES_SAMPLER_ARG", "0.0")
  let sampler = @sdk.Sampler::from_env()
  clear_sampler_env()
  assert_true(sampler.should_sample(None, env_trace_id(255)).is_sampled)
}

test "sampler_from_env_name_is_case_insensitive" {
  clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", " Always_Off ")
  let off = @sdk.Sampler::from_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "TRACEIDRATIO")
  @env.set_env_var("OTEL_TRACES_SAMPLER_ARG", "1.0")
  let ratio = @sdk.Sampler::from_env()
  clear_sampler_env()
  assert_false(off.should_sample(None, env_trace_id(255)).is_sampled)
  assert_true(ratio.should_sample(None, env_trace_id(255)).is_sampled)
}

test "sampler_from_env_parentbased_traceidratio_follows_parent" {
  clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "parentbased_traceidratio")
  @env.set_env_var("OTEL_TRACES_SAMPLER_ARG", "0.0")
  let sampler = @sdk.Sampler::from_env()
  clear_sampler_env()
  let sampled_parent = @api.span_context(
    Array::make(16, 3),
    Array::make(8, 4),
    @api.TRACE_FLAGS_SAMPLED,
  )
  assert_true(sampler.should_sample(Some(sampled_parent), env_trace_id(0)).is_sampled)
  assert_false(sampler.should_sample(None, env_trace_id(0)).is_sampled)
}

test "sampler_from_env_unknown_value_falls_back_to_default" {
  clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "no_such_sampler")
  let sampler = @sdk.Sampler::from_env()
  clear_sampler_env()
  assert_true(sampler.should_sample(None, env_trace_id(255)).is_sampled)
}

test "provider_uses_environment_sampler_by_default" {
  clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "always_off")
  let provider = @sdk.TracerProviderSdk::new(service_name="env-sampler")
  clear_sampler_env()
  let tracer = provider.get_tracer("env-sampler")
  let span = tracer.start_root_span("dropped")
  assert_false(span.is_recording())
}

test "explicit_sampler_overrides_the_environment" {
  clear_sampler_env()
  @env.set_env_var("OTEL_TRACES_SAMPLER", "always_off")
  let provider = @sdk.TracerProviderSdk::new(service_name="env-sampler")
    .with_sampler(@sdk.Sampler::always_on())
  clear_sampler_env()
  let tracer = provider.get_tracer("env-sampler")
  let span = tracer.start_root_span("recorded")
  assert_true(span.is_recording())
}

test "otel_sdk_disabled_drops_every_span" {
  clear_sampler_env()
  @env.set_env_var("OTEL_SDK_DISABLED", "true")
  let provider = @sdk.TracerProviderSdk::new(service_name="disabled")
  clear_sampler_env()
  let tracer = provider.get_tracer("disabled")
  let span = tracer.start_root_span("dropped")
  assert_false(span.is_recording())
  assert_false(span.context().is_sampled())
}
