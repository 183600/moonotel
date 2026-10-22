// Blackbox tests for `Tracer::enabled` and no-op behavior after the provider
// has been shut down.

///|
struct LifecycleExporter {
  spans : Array[@sdk.SpanData]
}

///|
pub impl @sdk.SpanExporter for LifecycleExporter with fn export_spans(
  self,
  spans,
) {
  for span in spans {
    self.spans.push(span)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for LifecycleExporter with fn shutdown(self) {
  let _ = self
}

// A processor that only counts lifecycle calls, used to observe provider
// shutdown behavior across copies.

///|
struct CountingProcessor {
  flushes : Ref[Int32]
  shutdowns : Ref[Int32]
}

///|
pub impl @sdk.SpanProcessor for CountingProcessor with fn on_start(
  self,
  _span,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CountingProcessor with fn on_end(self, _data) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CountingProcessor with fn force_flush(self) {
  self.flushes.val = self.flushes.val + 1
}

///|
pub impl @sdk.SpanProcessor for CountingProcessor with fn shutdown(self) {
  self.shutdowns.val = self.shutdowns.val + 1
}

///|
fn counting_processor() -> CountingProcessor {
  { flushes: Ref(0), shutdowns: Ref(0) }
}

///|
fn lifecycle_provider() -> (@sdk.TracerProviderSdk, LifecycleExporter) {
  let exporter : LifecycleExporter = { spans: [] }
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  (provider, exporter)
}

///|
test "tracer_enabled_reflects_processors_and_shutdown" {
  let (provider, _) = lifecycle_provider()
  let tracer = provider.get_tracer("lifecycle")
  assert_true(tracer.enabled())
  provider.shutdown()
  assert_false(tracer.enabled())
}

///|
test "tracer_without_processors_is_not_enabled" {
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("lifecycle")
  assert_false(tracer.enabled())
}

///|
test "spans_after_shutdown_are_not_recorded_or_exported" {
  let (provider, exporter) = lifecycle_provider()
  let tracer = provider.get_tracer("lifecycle")
  provider.shutdown()
  let span = tracer.start_span("after-shutdown")
  assert_false(span.is_recording())
  span.set_attribute("k", @sdk.StringValue("v"))
  span.end()
  assert_eq(span.attributes().length(), 0)
  assert_eq(exporter.spans.length(), 0)
}

///|
test "noop_span_wraps_parent_context" {
  let (provider, _) = lifecycle_provider()
  let tracer = provider.get_tracer("lifecycle")
  let parent = @api.span_context(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    [1, 2, 3, 4, 5, 6, 7, 8],
    @api.TRACE_FLAGS_SAMPLED,
  )
  provider.shutdown()
  let span = tracer.start_span("after-shutdown", parent~)
  assert_eq(span.context().trace_id_hex(), parent.trace_id_hex())
  assert_eq(span.context().span_id_hex(), parent.span_id_hex())
}

///|
test "noop_root_span_has_invalid_context" {
  let (provider, _) = lifecycle_provider()
  let tracer = provider.get_tracer("lifecycle")
  provider.shutdown()
  let span = tracer.start_span("after-shutdown")
  assert_false(span.context().is_valid())
}

///|
test "spans_ended_before_shutdown_are_still_exported" {
  let (provider, exporter) = lifecycle_provider()
  let tracer = provider.get_tracer("lifecycle")
  let span = tracer.start_span("before-shutdown")
  span.end()
  provider.shutdown()
  assert_eq(exporter.spans.length(), 1)
}

///|
test "shutdown_is_visible_across_provider_copies" {
  let (provider, _) = lifecycle_provider()
  let copy = provider.with_sampler(@sdk.Sampler::always_off())
  assert_false(copy.is_shutdown())
  provider.shutdown()
  assert_true(copy.is_shutdown())
}

///|
test "copy_shutdown_flushes_processors_added_to_the_copy" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_sampler(@sdk.Sampler::always_on())
  let copy = provider.with_span_processor(
    @sdk.BatchSpanProcessor::new(exporter, max_export_batch_size=100),
  )
  let tracer = copy.get_tracer("lifecycle")
  tracer.start_root_span("queued").end()
  assert_eq(exporter.span_count(), 0)
  provider.shutdown()
  assert_true(copy.is_shutdown())
  assert_false(exporter.is_shutdown())
  copy.shutdown()
  assert_eq(exporter.span_count(), 1)
  assert_true(exporter.is_shutdown())
}

///|
test "copy_shutdown_does_not_shut_a_shared_processor_twice" {
  let first = counting_processor()
  let second = counting_processor()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(first)
  let copy = provider.with_span_processor(second)
  provider.shutdown()
  assert_eq(first.shutdowns.val, 1)
  assert_eq(second.shutdowns.val, 0)
  copy.shutdown()
  assert_eq(first.shutdowns.val, 1)
  assert_eq(second.shutdowns.val, 1)
}

///|
test "force_flush_after_shutdown_is_ignored" {
  let processor = counting_processor()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(processor)
  provider.shutdown()
  assert_eq(processor.flushes.val, 0)
  provider.force_flush()
  assert_eq(processor.flushes.val, 0)
}
