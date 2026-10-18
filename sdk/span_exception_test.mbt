// Blackbox tests for SpanSdk::record_exception.

///|
struct ExceptionRecordingExporter {
  spans : Array[@sdk.SpanData]
}

///|
pub impl @sdk.SpanExporter for ExceptionRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for span in spans {
    self.spans.push(span)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for ExceptionRecordingExporter with fn shutdown(self) {
  let _ = self
}

///|
suberror TestError {
  TestError(String)
} derive(@debug.Debug)

///|
fn exception_test_setup(
  sampler : @sdk.Sampler,
) -> (@sdk.SpanSdk, ExceptionRecordingExporter) {
  let exporter : ExceptionRecordingExporter = { spans: [], }
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(sampler)
  (provider.get_tracer("t").start_root_span("op"), exporter)
}

///|
test "record_exception adds an exception event" {
  let (span, exporter) = exception_test_setup(@sdk.Sampler::always_on())
  span.record_exception(TestError("boom"), time_unix_nano=123L)
  span.end(end_time_unix_nano=200L)
  assert_eq(exporter.spans.length(), 1)
  let data = exporter.spans[0]
  assert_eq(data.events.length(), 1)
  assert_eq(data.events[0].name, "exception")
  assert_eq(data.events[0].time_unix_nano, 123L)
  match data.events[0].attributes.get(@sdk.EXCEPTION_MESSAGE) {
    Some(@sdk.StringValue(message)) => assert_true(message.contains("boom"))
    _ => fail("exception.message attribute is missing")
  }
  match data.events[0].attributes.get(@sdk.EXCEPTION_TYPE) {
    Some(@sdk.StringValue(type_name)) =>
      assert_true(type_name.contains("TestError"))
    _ => fail("exception.type attribute is missing")
  }
}

///|
test "record_exception honours the exception_type override" {
  let (span, exporter) = exception_test_setup(@sdk.Sampler::always_on())
  span.record_exception(TestError("boom"), exception_type="custom.Type")
  span.end()
  let data = exporter.spans[0]
  assert_eq(
    data.events[0].attributes.get(@sdk.EXCEPTION_TYPE),
    Some(@sdk.StringValue("custom.Type")),
  )
}

///|
test "record_exception is ignored on non-recording spans" {
  let (span, exporter) = exception_test_setup(@sdk.Sampler::always_off())
  assert_false(span.is_recording())
  span.record_exception(TestError("boom"))
  span.end()
  assert_eq(span.events().length(), 0)
  assert_eq(exporter.spans.length(), 0)
}

///|
test "record_exception is ignored after the span ends" {
  let (span, exporter) = exception_test_setup(@sdk.Sampler::always_on())
  span.end(end_time_unix_nano=100L)
  span.record_exception(TestError("late"))
  assert_eq(span.events().length(), 0)
  let data = exporter.spans[0]
  assert_eq(data.events.length(), 0)
}
