// Tests for the OTLP/HTTP exporter with the `http/json` protocol, using a
// mock transport that can answer with arbitrary bodies.

///|
struct JsonMockTransport {
  urls : Array[String]
  headers : Array[Map[String, String]]
  bodies : Array[Bytes]
  statuses : Array[Int32]
  response_bodies : Array[Bytes]
  default_status : Int32
  default_body : Bytes
}

///|
fn json_mock_transport(status : Int32, body : Bytes) -> JsonMockTransport {
  {
    urls: [],
    headers: [],
    bodies: [],
    statuses: [],
    response_bodies: [],
    default_status: status,
    default_body: body,
  }
}

///|
fn JsonMockTransport::as_transport(self : JsonMockTransport) -> @otlp.Transport {
  fn(url, headers, body) {
    self.urls.push(url)
    self.headers.push(headers)
    self.bodies.push(body)
    let status = if self.statuses.length() > 0 {
      self.statuses.remove(0)
    } else {
      self.default_status
    }
    let response_body = if self.response_bodies.length() > 0 {
      self.response_bodies.remove(0)
    } else {
      self.default_body
    }
    { status_code: status, body: response_body, }
  }
}

///|
test "json_export_sends_json_content_type_and_parsable_body" {
  let mock = json_mock_transport(200, b"{}")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    protocol="http/json",
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let result = exporter.export_spans([test_span()])
  assert_true(result.is_success())
  assert_eq(
    mock.headers[0].get("content-type"),
    Some("application/json"),
  )
  let text = @utf8.decode_lossy(mock.bodies[0].exact_view())
  let root = @json.parse(text) catch {
    err => abort("exporter sent invalid JSON: " + err.to_string())
  }
  assert_true(json_has_member(root, "resourceSpans"))
}

///|
test "json_export_partial_success_is_reported_as_failure" {
  let mock = json_mock_transport(
    200,
    b"{\"partialSuccess\":{\"rejectedSpans\":\"2\",\"errorMessage\":\"bad spans\"}}",
  )
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    protocol="http/json",
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  match exporter.export_spans([test_span()]) {
    @sdk.ExportFailure(message) => {
      assert_true(message.contains("rejected 2 span(s)"))
      assert_true(message.contains("bad spans"))
    }
    @sdk.ExportSuccess => fail("expected a partial success failure")
  }
}

///|
test "json_export_malformed_success_body_is_failure" {
  let mock = json_mock_transport(200, b"{")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    protocol="http/json",
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  assert_false(exporter.export_spans([test_span()]).is_success())
}

///|
test "json_export_retries_retryable_status" {
  let mock = json_mock_transport(200, b"{}")
  mock.statuses.push(503)
  mock.response_bodies.push(b"")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    protocol="http/json",
    max_retries=3,
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let result = exporter.export_spans([test_span()])
  assert_true(result.is_success())
  assert_eq(mock.urls.length(), 2)
}

///|
test "json_export_does_not_retry_non_retryable_status" {
  let mock = json_mock_transport(400, b"")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    protocol="http/json",
    max_retries=3,
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  assert_false(exporter.export_spans([test_span()]).is_success())
  assert_eq(mock.urls.length(), 1)
}

///|
test "json_export_rejects_unsupported_protocol" {
  let mock = json_mock_transport(200, b"{}")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    protocol="grpc",
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  match exporter.export_spans([test_span()]) {
    @sdk.ExportFailure(message) =>
      assert_true(message.contains("unsupported OTLP protocol: grpc"))
    @sdk.ExportSuccess => fail("expected the grpc protocol to be rejected")
  }
  assert_eq(mock.urls.length(), 0)
}

///|
test "json_export_empty_batch_skips_transport" {
  let mock = json_mock_transport(200, b"{}")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    protocol="http/json",
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  assert_true(exporter.export_spans([]).is_success())
  assert_eq(mock.urls.length(), 0)
}

///|
test "protocol_helpers" {
  assert_true(@otlp.is_supported_protocol(@otlp.OTLP_HTTP_PROTOBUF_PROTOCOL))
  assert_true(@otlp.is_supported_protocol(@otlp.OTLP_HTTP_JSON_PROTOCOL))
  assert_false(@otlp.is_supported_protocol("grpc"))
  assert_eq(
    @otlp.content_type_for_protocol(@otlp.OTLP_HTTP_JSON_PROTOCOL),
    "application/json",
  )
  assert_eq(
    @otlp.content_type_for_protocol(@otlp.OTLP_HTTP_PROTOBUF_PROTOCOL),
    "application/x-protobuf",
  )
}
