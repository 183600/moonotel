// Tests for the `AlwaysRecord` sampler decorator, which keeps every span
// recorded while preserving the wrapped sampler's export decision.

///|
fn always_record_trace_id(byte : Int32) -> Array[Int32] {
  let id : Array[Int32] = [byte]
  while id.length() < 16 {
    id.push(0)
  }
  id
}

///|
test "always_record_keeps_a_sampled_decision" {
  let sampler = @sdk.Sampler::always_record(@sdk.Sampler::always_on())
  let decision = sampler.should_sample(None, always_record_trace_id(1))
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

///|
test "always_record_converts_drop_to_record_only" {
  let sampler = @sdk.Sampler::always_record(@sdk.Sampler::always_off())
  let decision = sampler.should_sample(None, always_record_trace_id(1))
  assert_true(decision.is_recorded)
  assert_false(decision.is_sampled)
}

///|
test "always_record_keeps_record_only" {
  let sampler = @sdk.Sampler::always_record(@sdk.Sampler::record_only())
  let decision = sampler.should_sample(None, always_record_trace_id(1))
  assert_true(decision.is_recorded)
  assert_false(decision.is_sampled)
}

///|
test "always_record_describes_the_wrapped_sampler" {
  assert_eq(
    @sdk.Sampler::always_record(@sdk.Sampler::always_off()).description(),
    "AlwaysRecord{AlwaysOffSampler}",
  )
}

///|
test "always_record_spans_are_readable_but_not_exported" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(
    service_name="always-record",
  )
    .with_sampler(@sdk.Sampler::always_record(@sdk.Sampler::always_off()))
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("always-record")
  let span = tracer.start_root_span("recorded-only")
  assert_true(span.is_recording())
  span.set_string_attribute("key", "value")
  span.add_event("event")
  span.end()
  assert_eq(exporter.span_count(), 0)
  assert_eq(span.attributes().get("key"), Some(@sdk.StringValue("value")))
  assert_eq(span.events().length(), 1)
}
