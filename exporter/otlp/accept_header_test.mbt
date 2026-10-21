// The OTLP/HTTP exporter announces the response format it accepts, as the
// OTLP/HTTP specification asks the client to do.

///|
struct AcceptMockTransport {
  headers : Array[Map[String, String]]
}

///|
fn accept_mock_transport() -> AcceptMockTransport {
  { headers: [], }
}

///|
fn AcceptMockTransport::as_transport(
  self : AcceptMockTransport,
) -> @otlp.Transport {
  fn(_url, headers, _body) {
    self.headers.push(headers)
    { status_code: 200, body: b"", }
  }
}

///|
fn accept_test_span() -> @sdk.SpanData {
  {
    name: "op",
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map([]),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(Map([])),
    scope_name: "scope",
    scope_version: "",
  }
}

///|
test "export_announces_the_protobuf_format_it_accepts" {
  let mock = accept_mock_transport()
  let config = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318")
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  assert_true(exporter.export_spans([accept_test_span()]).is_success())
  assert_eq(mock.headers.length(), 1)
  assert_eq(mock.headers[0].get("accept"), Some("application/x-protobuf"))
  assert_eq(mock.headers[0].get("content-type"), Some("application/x-protobuf"))
}

///|
test "export_announces_the_json_format_it_accepts" {
  let mock = accept_mock_transport()
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    protocol=@otlp.OTLP_HTTP_JSON_PROTOCOL,
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  assert_true(exporter.export_spans([accept_test_span()]).is_success())
  assert_eq(mock.headers.length(), 1)
  assert_eq(mock.headers[0].get("accept"), Some("application/json"))
  assert_eq(mock.headers[0].get("content-type"), Some("application/json"))
}

///|
test "a_configured_accept_header_is_replaced" {
  let mock = accept_mock_transport()
  let headers : Map[String, String] = Map([], capacity=1)
  headers.set("Accept", "text/plain")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers~,
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  assert_true(exporter.export_spans([accept_test_span()]).is_success())
  assert_eq(mock.headers.length(), 1)
  assert_eq(mock.headers[0].get("accept"), Some("application/x-protobuf"))
  assert_eq(mock.headers[0].get("Accept"), None)
}
