// An explicit URI port of 0 is syntactically valid and must be recorded as
// `server.port`; only an absent or invalid port is omitted.

///|
struct ZeroPortRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for ZeroPortRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for ZeroPortRecordingExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
async test "client span records an explicit zero server port" {
  let exporter : ZeroPortRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="zero-port-client-test",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("zero-port-client-test")
  // Connecting to port 0 fails, but the span attributes are recorded before
  // the request attempt, so the exported span still carries the parsed port.
  let failed = try {
    let (_response, _body) = @async_http_client.get(
      "http://example.com:0/path",
      tracer~,
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(exporter.spans.val.length(), 1)
  let data = exporter.spans.val[0]
  assert_eq(
    data.attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("example.com")),
  )
  assert_eq(
    data.attributes.get(@sdk.SERVER_PORT),
    Some(@sdk.IntValue(0)),
  )
}
