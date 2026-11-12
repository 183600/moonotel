///|
test "exporter rejects a request larger than the configured limit" {
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318"),
    mock.as_transport(),
    max_request_size=1,
  )
  let result = exporter.export_spans([test_span()])
  match result {
    @sdk.ExportFailure(message) => assert_true(message.contains("1-byte"))
    @sdk.ExportSuccess => abort("expected a request size-limit failure")
  }
  assert_eq(mock.urls.length(), 0)
}

///|
test "exporter treats a non-positive request limit as the default" {
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318"),
    mock.as_transport(),
    max_request_size=0,
    max_response_size=-1,
  )
  assert_true(exporter.export_spans([test_span()]).is_success())
  assert_eq(mock.urls.length(), 1)
}

///|
test "exporter applies the configured response size limit" {
  let transport : @otlp.Transport = fn(_url, _headers, _body) {
    { status_code: 200, body: b"\x0A\x00", }
  }
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318"),
    transport,
    max_response_size=1,
  )
  let result = exporter.export_spans([test_span()])
  match result {
    @sdk.ExportFailure(message) => assert_true(message.contains("1-byte"))
    @sdk.ExportSuccess => abort("expected a response size-limit failure")
  }
}

///|
test "exporter applies the configured response size limit to JSON" {
  let transport : @otlp.Transport = fn(_url, _headers, _body) {
    { status_code: 200, body: b"{}", }
  }
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(
      endpoint="http://collector:4318",
      protocol=@otlp.OTLP_HTTP_JSON_PROTOCOL,
    ),
    transport,
    max_response_size=1,
  )
  let result = exporter.export_spans([test_span()])
  match result {
    @sdk.ExportFailure(message) => assert_true(message.contains("1-byte"))
    @sdk.ExportSuccess => abort("expected a response size-limit failure")
  }
}

///|
test "exporter accepts a response at the configured limit" {
  let transport : @otlp.Transport = fn(_url, _headers, _body) {
    { status_code: 200, body: b"\x0A\x00", }
  }
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318"),
    transport,
    max_response_size=2,
  )
  assert_true(exporter.export_spans([test_span()]).is_success())
}
