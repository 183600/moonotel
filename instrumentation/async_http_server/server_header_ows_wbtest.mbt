// Header values parsed by the instrumentation must be trimmed of HTTP
// optional whitespace (SP / HTAB) before numeric or authority parsing: the
// HTTP reader strips at most one leading space and keeps trailing whitespace.

///|
fn ows_header_map(entries : Array[(String, String)]) -> Map[
  @http.CaseInsensitiveString,
  String,
] {
  let headers : Map[@http.CaseInsensitiveString, String] = Map([])
  for entry in entries {
    headers.set(@http.CaseInsensitiveString(entry.0), entry.1)
  }
  headers
}

///|
test "request_body_size trims optional whitespace around content-length" {
  let headers = ows_header_map([("Content-Length", " 5 \t")])
  assert_eq(request_body_size(headers), Some(5L))
}

///|
test "request_body_size ignores content-length when transfer-encoding is set" {
  let headers = ows_header_map([
    ("Transfer-Encoding", " chunked "),
    ("Content-Length", "5"),
  ])
  assert_eq(request_body_size(headers), None)
}

///|
fn host_attribute_span() -> (@sdk.SpanSdk, @sdk.InMemorySpanExporter) {
  let exporter = @sdk.InMemorySpanExporter::new()
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="header-ows-test",
  ).with_span_processor(processor)
  let span = provider.get_tracer("header-ows-test").start_root_span("host")
  (span, exporter)
}

///|
test "record_host_attributes trims optional whitespace around the host" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(
    span,
    ows_header_map([("Host", " example.com:8080 \t")]),
    "/",
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(
    data.attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("example.com")),
  )
  assert_eq(
    data.attributes.get(@sdk.SERVER_PORT),
    Some(@sdk.IntValue(8080)),
  )
}

///|
test "record_host_attributes omits an empty host" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(
    span,
    ows_header_map([("Host", " \t ")]),
    "/",
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.get(@sdk.SERVER_ADDRESS), None)
  assert_eq(data.attributes.get(@sdk.SERVER_PORT), None)
}

///|
test "record_host_attributes ignores host for an absolute target without authority" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(
    span,
    ows_header_map([("Host", "external.example.com")]),
    "http:///path",
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.get(@sdk.SERVER_ADDRESS), None)
  assert_eq(data.attributes.get(@sdk.SERVER_PORT), None)
}
