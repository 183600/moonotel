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

///|
test "a decorator drops when its delegate is shut down directly" {
  let root_calls = Ref(0)
  let root = counting_sampler(root_calls)
  let always_record = @sdk.Sampler::always_record(root)
  assert_true(always_record.should_sample(None, Array::make(16, 1)).is_sampled)
  root.shutdown()
  let recorded = always_record.should_sample(None, Array::make(16, 1))
  assert_false(recorded.is_recorded)
  assert_false(recorded.is_sampled)

  let delegate_calls = Ref(0)
  let delegate = counting_sampler(delegate_calls)
  let parent_based = @sdk.Sampler::parent_based(
    @sdk.Sampler::always_on(),
    local_parent_sampled=delegate,
  )
  let trace_id = Array::make(16, 1)
  let parent = @api.span_context(
    trace_id,
    Array::make(8, 2),
    @api.TRACE_FLAGS_SAMPLED,
  )
  assert_true(parent_based.should_sample(Some(parent), trace_id).is_sampled)
  delegate.shutdown()
  let sampled = parent_based.should_sample(Some(parent), trace_id)
  assert_false(sampled.is_recorded)
  assert_false(sampled.is_sampled)
}

///|
test "parent_based keeps using parent delegates after its root is shut down" {
  let root = @sdk.Sampler::always_on()
  let sampler = @sdk.Sampler::parent_based(
    root,
    local_parent_sampled=@sdk.Sampler::always_on(),
  )
  let trace_id = Array::make(16, 1)
  let parent = @api.span_context(
    trace_id,
    Array::make(8, 2),
    @api.TRACE_FLAGS_SAMPLED,
  )
  assert_true(sampler.should_sample(None, trace_id).is_sampled)
  assert_true(sampler.should_sample(Some(parent), trace_id).is_sampled)
  root.shutdown()
  let rootless = sampler.should_sample(None, trace_id)
  assert_false(rootless.is_recorded)
  assert_false(rootless.is_sampled)
  let with_parent = sampler.should_sample(Some(parent), trace_id)
  assert_true(with_parent.is_recorded)
  assert_true(with_parent.is_sampled)
}

///|
test "with_shutdown on a composite keeps delegate forwarding" {
  let parent_calls = Ref(0)
  let parent_root_calls = Ref(0)
  let extra_calls = Ref(0)
  let parent_root = counting_sampler(parent_root_calls)
  let parent = @sdk.Sampler::parent_based(parent_root)
    .with_shutdown(fn() { parent_calls.val = parent_calls.val + 1 })
    .with_shutdown(fn() { extra_calls.val = extra_calls.val + 1 })
  parent.shutdown()
  assert_eq(parent_calls.val, 1)
  assert_eq(extra_calls.val, 1)
  assert_eq(parent_root_calls.val, 1)

  let record_calls = Ref(0)
  let record_root_calls = Ref(0)
  let record_root = counting_sampler(record_root_calls)
  let record = @sdk.Sampler::always_record(record_root)
    .with_shutdown(fn() { record_calls.val = record_calls.val + 1 })
  record.shutdown()
  assert_eq(record_calls.val, 1)
  assert_eq(record_root_calls.val, 1)
}
