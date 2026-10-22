// A URL without an authority has no known server address; the instrumentation
// must not record an empty `server.address` (or its default port).

///|
struct EmptyHostRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for EmptyHostRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for EmptyHostRecordingExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
async test "client span omits server attributes for a URL without a host" {
  let exporter : EmptyHostRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="empty-host-test",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("empty-host-test")
  let failed = try {
    let (_response, _body) = @async_http_client.get(
      "http:///no-authority",
      tracer~,
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(exporter.spans.val.length(), 1)
  let data = exporter.spans.val[0]
  assert_eq(data.attributes.get(@sdk.SERVER_ADDRESS), None)
  assert_eq(data.attributes.get(@sdk.SERVER_PORT), None)
}
