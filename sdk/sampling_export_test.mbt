// Blackbox tests that recording-but-unsampled spans are kept out of exporters.

///|
struct SamplingRecordingExporter {
  spans : Array[@sdk.SpanData]
}

///|
fn sampling_recording_exporter() -> SamplingRecordingExporter {
  { spans: [], }
}

///|
pub impl @sdk.SpanExporter for SamplingRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for span in spans {
    self.spans.push(span)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for SamplingRecordingExporter with fn shutdown(self) {
  let _ = self
}

///|
test "record_only_span_is_not_exported_by_simple_processor" {
  let exporter = sampling_recording_exporter()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::record_only())
  let span = provider.get_tracer("t").start_root_span("op")
  assert_true(span.is_recording())
  assert_false(span.context().is_sampled())
  span.set_attribute("k", @sdk.StringValue("v"))
  assert_eq(span.attributes().length(), 1)
  span.end()
  assert_eq(exporter.spans.length(), 0)
}

///|
test "record_only_span_is_not_exported_by_batch_processor" {
  let exporter = sampling_recording_exporter()
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=1,
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(processor)
    .with_sampler(@sdk.Sampler::record_only())
  provider.get_tracer("t").start_root_span("op").end()
  assert_eq(processor.queue_size(), 0)
  provider.force_flush()
  assert_eq(exporter.spans.length(), 0)
}

///|
test "sampled_span_is_still_exported" {
  let exporter = sampling_recording_exporter()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc").with_span_processor(
    @sdk.SimpleSpanProcessor::new(exporter),
  )
  provider.get_tracer("t").start_root_span("op").end()
  assert_eq(exporter.spans.length(), 1)
}
