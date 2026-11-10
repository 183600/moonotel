// Tests for `OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SANITIZE_FIELDS`:
// captured headers selected for sanitization keep their attribute but their
// value is replaced with `[REDACTED]`.

///|
struct SanitizeRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for SanitizeRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for SanitizeRecordingExporter with fn shutdown(self) {
  let _ = self
}

///|
fn sanitize_test_span() -> (@sdk.SpanSdk, SanitizeRecordingExporter) {
  let exporter : SanitizeRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="header-sanitize-test",
  ).with_span_processor(processor)
  (provider.get_tracer("header-sanitize-test").start_span("test"), exporter)
}

///|
test "sanitize fields redact matching captured headers" {
  let (span, exporter) = sanitize_test_span()
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Authorization"), "Bearer secret"),
    (@http.CaseInsensitiveString("X-Custom"), "custom"),
  ])
  let capture = @http_header_capture.HeaderCapture::parse(
    "authorization,x-custom",
  ).with_sanitize("Authorization")
  capture.record_request(headers, span)
  span.end()
  let data = exporter.spans.val[0]
  assert_eq(
    data.attributes.get("http.request.header.authorization"),
    Some(@sdk.StringArrayValue(["[REDACTED]"])),
  )
  assert_eq(
    data.attributes.get("http.request.header.x-custom"),
    Some(@sdk.StringArrayValue(["custom"])),
  )
}

///|
test "sanitize wildcard redacts every captured header" {
  let (span, exporter) = sanitize_test_span()
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("X-One"), "1"),
    (@http.CaseInsensitiveString("X-Two"), "2"),
  ])
  let capture = @http_header_capture.HeaderCapture::parse("*").with_sanitize(
    "*",
  )
  capture.record_response(headers, span)
  span.end()
  let data = exporter.spans.val[0]
  assert_eq(
    data.attributes.get("http.response.header.x-one"),
    Some(@sdk.StringArrayValue(["[REDACTED]"])),
  )
  assert_eq(
    data.attributes.get("http.response.header.x-two"),
    Some(@sdk.StringArrayValue(["[REDACTED]"])),
  )
}

///|
test "blank sanitize configuration leaves captured values unchanged" {
  let (span, exporter) = sanitize_test_span()
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("X-One"), "1"),
  ])
  let capture = @http_header_capture.HeaderCapture::parse("x-one").with_sanitize(
    " , \t,",
  )
  capture.record_request(headers, span)
  span.end()
  let data = exporter.spans.val[0]
  assert_eq(
    data.attributes.get("http.request.header.x-one"),
    Some(@sdk.StringArrayValue(["1"])),
  )
}

///|
test "from_env applies the sanitize fields variable" {
  let capture_variable = "MOONOTEL_TEST_HEADER_CAPTURE_SANITIZE_ENV"
  @env.set_env_var(capture_variable, "authorization,x-keep")
  @env.set_env_var(@http_header_capture.ENV_SANITIZE_FIELDS, "AUTHORIZATION")
  defer @env.unset_env_var(capture_variable)
  defer @env.unset_env_var(@http_header_capture.ENV_SANITIZE_FIELDS)
  let capture = @http_header_capture.HeaderCapture::from_env(capture_variable)
  assert_true(capture.captures("authorization"))
  assert_true(capture.captures("x-keep"))
  assert_true(capture.sanitizes("Authorization"))
  assert_false(capture.sanitizes("x-keep"))
}

///|
test "from_env notices sanitize field changes while capture is unchanged" {
  let capture_variable = "MOONOTEL_TEST_HEADER_CAPTURE_SANITIZE_CACHE"
  @env.set_env_var(capture_variable, "x-one")
  @env.unset_env_var(@http_header_capture.ENV_SANITIZE_FIELDS)
  defer @env.unset_env_var(capture_variable)
  defer @env.unset_env_var(@http_header_capture.ENV_SANITIZE_FIELDS)
  let first = @http_header_capture.HeaderCapture::from_env(capture_variable)
  assert_false(first.sanitizes("x-one"))
  @env.set_env_var(@http_header_capture.ENV_SANITIZE_FIELDS, "x-one")
  let second = @http_header_capture.HeaderCapture::from_env(capture_variable)
  assert_true(second.sanitizes("x-one"))
  @env.unset_env_var(@http_header_capture.ENV_SANITIZE_FIELDS)
  let third = @http_header_capture.HeaderCapture::from_env(capture_variable)
  assert_false(third.sanitizes("x-one"))
}
