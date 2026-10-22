// A relative URL has no scheme and no authority, so it cannot supply a known
// server address or port. The client span must not interpret its first path
// segment as a host.

///|
struct RelativeUrlRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for RelativeUrlRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for RelativeUrlRecordingExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
async test "client span omits server attributes for a relative URL" {
  let exporter : RelativeUrlRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="relative-url-test",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("relative-url-test")
  // The HTTP client rejects a relative reference immediately, before any
  // network access; the span attributes are still recorded.
  let failed = try {
    let (_response, _body) = @async_http_client.get(
      "example.com/path",
      tracer~,
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(exporter.spans.val.length(), 1)
  let data = exporter.spans.val[0]
  assert_eq(data.attributes.get(@sdk.URL_SCHEME), None)
  assert_eq(data.attributes.get(@sdk.SERVER_ADDRESS), None)
  assert_eq(data.attributes.get(@sdk.SERVER_PORT), None)
}
