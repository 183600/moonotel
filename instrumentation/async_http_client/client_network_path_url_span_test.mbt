// A network-path reference carries its authority in `url.full` after
// redaction, but `url.path`/`url.query` must describe only the request target.

///|
struct NetworkPathUrlExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for NetworkPathUrlExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for NetworkPathUrlExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
pub extend NetworkPathUrlExporter with @sdk.SpanExporter::{export_spans, shutdown}

///|
async test "client network-path url attributes omit credentials" {
  let exporter : NetworkPathUrlExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="network-path-url",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("network-path-url")
  let failed = try {
    let (_response, _body) = @async_http_client.get(
      "//user:pass@example.com/path?q=1",
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
    data.attributes.get(@sdk.URL_FULL),
    Some(@sdk.StringValue("//example.com/path?q=1")),
  )
  assert_eq(
    data.attributes.get(@sdk.URL_PATH),
    Some(@sdk.StringValue("/path")),
  )
  assert_eq(
    data.attributes.get(@sdk.URL_QUERY),
    Some(@sdk.StringValue("q=1")),
  )
  assert_eq(data.attributes.get(@sdk.URL_SCHEME), None)
  assert_eq(data.attributes.get(@sdk.SERVER_ADDRESS), None)
  assert_eq(data.attributes.get(@sdk.SERVER_PORT), None)
}
