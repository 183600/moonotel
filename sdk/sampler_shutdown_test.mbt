// Sampler shutdown is part of the OpenTelemetry sampler lifecycle: owners
// release sampler resources once, decorators forward the call to delegates,
// and a shut-down sampler drops further decisions.

///|
fn counting_sampler(calls : Ref[Int]) -> @sdk.Sampler {
  @sdk.Sampler::new("CountingSampler", fn(_parameters) {
    @sdk.sampling_decision_record_and_sample()
  }).with_shutdown(fn() { calls.val = calls.val + 1 })
}

///|
test "provider shutdown shuts the sampler down once" {
  let calls = Ref(0)
  let provider = @sdk.TracerProviderSdk::new(service_name="sampler-shutdown")
    .with_sampler(counting_sampler(calls))
  provider.shutdown()
  assert_eq(calls.val, 1)
  provider.shutdown()
  assert_eq(calls.val, 1)
}

///|
test "composite samplers forward shutdown to their delegates" {
  let root_calls = Ref(0)
  let remote_calls = Ref(0)
  let local_calls = Ref(0)
  let parent_based = @sdk.Sampler::parent_based(
    counting_sampler(root_calls),
    remote_parent_sampled=counting_sampler(remote_calls),
    local_parent_not_sampled=counting_sampler(local_calls),
  )
  let sampler = @sdk.Sampler::always_record(parent_based)
  sampler.shutdown()
  assert_eq(root_calls.val, 1)
  assert_eq(remote_calls.val, 1)
  assert_eq(local_calls.val, 1)
  sampler.shutdown()
  assert_eq(root_calls.val, 1)
  assert_eq(remote_calls.val, 1)
  assert_eq(local_calls.val, 1)
}

///|
test "a shut-down sampler drops further decisions" {
  let calls = Ref(0)
  let sampler = counting_sampler(calls)
  let before = sampler.should_sample(None, Array::make(16, 1))
  assert_true(before.is_recorded)
  assert_true(before.is_sampled)
  sampler.shutdown()
  let after = sampler.should_sample(None, Array::make(16, 1))
  assert_false(after.is_recorded)
  assert_false(after.is_sampled)
  assert_eq(calls.val, 1)
}
