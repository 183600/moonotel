// Tests for parsing the header-capture configuration and recording captured
// headers as span attributes.

///|
struct CaptureRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for CaptureRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for CaptureRecordingExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
fn capture_span() -> (@sdk.SpanSdk, CaptureRecordingExporter) {
  let exporter : CaptureRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="header-capture-test",
  ).with_span_processor(processor)
  (provider.get_tracer("header-capture-test").start_span("test"), exporter)
}

///|
test "parse trims names, ignores empty entries and lower-cases names" {
  let capture = @http_header_capture.HeaderCapture::parse(
    " User-Agent , ,X-CUSTOM,x-custom ",
  )
  assert_true(capture.is_enabled())
  assert_true(capture.captures("user-agent"))
  assert_true(capture.captures("User-Agent"))
  assert_true(capture.captures("x-custom"))
  assert_false(capture.captures("x-other"))
}

///|
test "parse of a blank configuration captures nothing" {
  let capture = @http_header_capture.HeaderCapture::parse("  , \t,")
  assert_false(capture.is_enabled())
  assert_false(capture.captures("user-agent"))
}

///|
test "wildcard captures every header" {
  let capture = @http_header_capture.HeaderCapture::parse("*")
  assert_true(capture.is_enabled())
  assert_true(capture.captures("anything"))
  assert_true(capture.captures(""))
}

///|
test "from_env reads the configured variable" {
  @env.set_env_var(
    @http_header_capture.ENV_CLIENT_REQUEST_HEADERS,
    "X-Trace-Id",
  )
  defer @env.unset_env_var(@http_header_capture.ENV_CLIENT_REQUEST_HEADERS)
  let capture = @http_header_capture.HeaderCapture::from_env(
    @http_header_capture.ENV_CLIENT_REQUEST_HEADERS,
  )
  assert_true(capture.captures("x-trace-id"))
  assert_false(capture.captures("x-other"))
  assert_false(
    @http_header_capture.HeaderCapture::from_env(
      @http_header_capture.ENV_SERVER_RESPONSE_HEADERS,
    ).is_enabled(),
  )
}

///|
test "record_request and record_response lower-case and prefix keys" {
  let (span, exporter) = capture_span()
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("X-Custom"), "custom-value"),
    (@http.CaseInsensitiveString("User-Agent"), "agent/1.0"),
  ])
  let capture = @http_header_capture.HeaderCapture::parse("x-custom,user-agent")
  capture.record_request(headers, span)
  capture.record_response(headers, span)
  span.end()
  assert_eq(exporter.spans.val.length(), 1)
  let data = exporter.spans.val[0]
  assert_eq(
    data.attributes.get("http.request.header.x-custom"),
    Some(@sdk.StringArrayValue(["custom-value"])),
  )
  assert_eq(
    data.attributes.get("http.request.header.user-agent"),
    Some(@sdk.StringArrayValue(["agent/1.0"])),
  )
  assert_eq(
    data.attributes.get("http.response.header.x-custom"),
    Some(@sdk.StringArrayValue(["custom-value"])),
  )
  assert_eq(
    data.attributes.get("http.response.header.user-agent"),
    Some(@sdk.StringArrayValue(["agent/1.0"])),
  )
}

///|
test "wildcard records all headers with lower-case names" {
  let (span, exporter) = capture_span()
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("X-One"), "1"),
    (@http.CaseInsensitiveString("X-Two"), "2"),
  ])
  @http_header_capture.HeaderCapture::parse("*").record_request(headers, span)
  span.end()
  let data = exporter.spans.val[0]
  assert_eq(
    data.attributes.get("http.request.header.x-one"),
    Some(@sdk.StringArrayValue(["1"])),
  )
  assert_eq(
    data.attributes.get("http.request.header.x-two"),
    Some(@sdk.StringArrayValue(["2"])),
  )
}

///|
test "disabled capture records nothing" {
  let (span, exporter) = capture_span()
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("X-One"), "1"),
  ])
  let capture = @http_header_capture.HeaderCapture::parse("")
  capture.record_request(headers, span)
  capture.record_response(headers, span)
  span.end()
  let data = exporter.spans.val[0]
  assert_eq(data.attributes.get("http.request.header.x-one"), None)
  assert_eq(data.attributes.get("http.response.header.x-one"), None)
}

///|
test "captured header values omit surrounding optional whitespace" {
  let (span, exporter) = capture_span()
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("X-Padded"), " \tvalue  "),
    (@http.CaseInsensitiveString("X-Other"), "\t other \t"),
  ])
  let capture = @http_header_capture.HeaderCapture::parse("x-padded,*")
  capture.record_request(headers, span)
  span.end()
  let data = exporter.spans.val[0]
  assert_eq(
    data.attributes.get("http.request.header.x-padded"),
    Some(@sdk.StringArrayValue(["value"])),
  )
  assert_eq(
    data.attributes.get("http.request.header.x-other"),
    Some(@sdk.StringArrayValue(["other"])),
  )
}
