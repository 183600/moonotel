// Regression tests for SpanSdk mutator semantics and processor notification
// rules on non-recording spans.

struct StartCounter {
  mut starts : Int
}

pub impl @sdk.SpanProcessor for StartCounter with on_start(self, _span) {
  self.starts = self.starts + 1
}

pub impl @sdk.SpanProcessor for StartCounter with on_end(_self, _data) {
}

pub impl @sdk.SpanProcessor for StartCounter with force_flush(_self) {
}

pub impl @sdk.SpanProcessor for StartCounter with shutdown(_self) {
}

test "non_recording_span_ignores_update_name" {
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_sampler(@sdk.Sampler::always_off())
  let span = provider.get_tracer("t").start_root_span("original")
  assert_false(span.is_recording())
  span.update_name("changed")
  assert_eq(span.name(), "original")
  span.end()
}

test "non_recording_span_skips_processor_on_start" {
  let counter : StartCounter = { starts: 0 }
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(counter)
    .with_sampler(@sdk.Sampler::always_off())
  let span = provider.get_tracer("t").start_root_span("op")
  assert_false(span.is_recording())
  assert_eq(counter.starts, 0)
  span.end()
}

test "recording_span_notifies_processor_on_start" {
  let counter : StartCounter = { starts: 0 }
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(counter)
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("t").start_root_span("op")
  assert_true(span.is_recording())
  assert_eq(counter.starts, 1)
  span.end()
}

test "ok_status_is_final_and_description_only_for_error" {
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("t").start_root_span("op")
  span.set_status(@api.StatusCode::Ok, description="ignored")
  assert_eq(span.status(), @api.StatusCode::Ok)
  assert_eq(span.status_description(), "")
  span.set_status(@api.StatusCode::Error, description="late")
  assert_eq(span.status(), @api.StatusCode::Ok)
  assert_eq(span.status_description(), "")
  span.end()
}

test "unset_attempt_is_ignored" {
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("t").start_root_span("op")
  span.set_status(@api.StatusCode::Error, description="boom")
  span.set_status(@api.StatusCode::Unset, description="ignored")
  assert_eq(span.status(), @api.StatusCode::Error)
  assert_eq(span.status_description(), "boom")
  span.end()
}
