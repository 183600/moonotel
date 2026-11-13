// White-box tests for the lazily derived default tracer. The instrumentation
// must follow the process-wide provider and drop its cached tracer when the
// provider is replaced or removed.

///|
struct DefaultTracerExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for DefaultTracerExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for DefaultTracerExporter with fn shutdown(self) {
  let _ = self
}

///|
fn default_tracer_provider(
  service_name : String,
) -> (@sdk.TracerProviderSdk, DefaultTracerExporter) {
  let exporter : DefaultTracerExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(service_name~).with_span_processor(
    processor,
  )
  (provider, exporter)
}

///|
test "default_tracer_follows_the_global_provider" {
  @sdk.shutdown_global_tracer_provider()
  defer @sdk.shutdown_global_tracer_provider()
  let (first_provider, first_exporter) = default_tracer_provider("first")
  @sdk.set_global_tracer_provider(first_provider)
  let first_tracer = default_tracer().unwrap()
  first_tracer.start_root_span("first").end()
  assert_eq(first_exporter.spans.val.length(), 1)
  let (second_provider, second_exporter) = default_tracer_provider("second")
  @sdk.set_global_tracer_provider(second_provider)
  let second_tracer = default_tracer().unwrap()
  second_tracer.start_root_span("second").end()
  assert_eq(second_exporter.spans.val.length(), 1)
  assert_eq(first_exporter.spans.val.length(), 1)
  @sdk.shutdown_global_tracer_provider()
  assert_true(default_tracer() is None)
  assert_true(default_tracer_cache.val is None)
}

///|
test "default_tracer_reuses_the_cached_tracer_for_the_same_provider" {
  @sdk.shutdown_global_tracer_provider()
  defer @sdk.shutdown_global_tracer_provider()
  let (provider, _) = default_tracer_provider("cache")
  @sdk.set_global_tracer_provider(provider)
  let first = default_tracer().unwrap()
  let cached_provider = default_tracer_cache.val.unwrap().0
  let second = default_tracer().unwrap()
  assert_true(physical_equal(cached_provider, provider))
  assert_true(physical_equal(first, second))
}

///|
pub extend DefaultTracerExporter with @sdk.SpanExporter::{
  export_spans,
  export_span,
  shutdown,
}
