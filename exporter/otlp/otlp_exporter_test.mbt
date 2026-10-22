// Blackbox tests for the OTLP/HTTP exporter using a mock transport.

///|
struct MockTransport {
  urls : Array[String]
  bodies : Array[Bytes]
  headers : Array[Map[String, String]]
  responses : Array[Int32]
  default_status : Int32
}

///|
fn mock_transport(status : Int32) -> MockTransport {
  { urls: [], bodies: [], headers: [], responses: [], default_status: status, }
}

///|
fn MockTransport::as_transport(self : MockTransport) -> @otlp.Transport {
  fn(url, headers, body) {
    self.urls.push(url)
    self.bodies.push(body)
    self.headers.push(headers)
    let status = if self.responses.length() > 0 {
      self.responses.remove(0)
    } else {
      self.default_status
    }
    { status_code: status, body: b"", }
  }
}

///|
fn test_span() -> @sdk.SpanData {
  let resource : Map[String, @sdk.AttributeValue] = Map([], capacity=1)
  resource.set(@sdk.SERVICE_NAME, @sdk.StringValue("exporter-test"))
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
    attributes: Map([], capacity=1),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(resource),
    scope_name: "scope",
    scope_version: "",
  }
}

///|
test "export_posts_protobuf_to_v1_traces" {
  let mock = mock_transport(200)
  let config = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318")
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let result = exporter.export_spans([test_span()])
  assert_true(result.is_success())
  assert_eq(mock.urls.length(), 1)
  assert_eq(mock.urls[0], "http://collector:4318/v1/traces")
  assert_eq(mock.headers[0].get("content-type"), Some("application/x-protobuf"))
  assert_true(mock.bodies[0].equal(@otlp.encode_trace_request([test_span()])))
}

///|
test "export_keeps_endpoint_trailing_slash" {
  let mock = mock_transport(200)
  let config = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318/")
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let _ = exporter.export_spans([test_span()])
  assert_eq(mock.urls[0], "http://collector:4318/v1/traces")
}

///|
test "explicit_traces_endpoint_is_used_verbatim" {
  let mock = mock_transport(200)
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    traces_endpoint="http://gateway:443/custom/traces",
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let _ = exporter.export_spans([test_span()])
  assert_eq(mock.urls[0], "http://gateway:443/custom/traces")
}

///|
test "export_passes_custom_headers" {
  let mock = mock_transport(200)
  let headers : Map[String, String] = Map([], capacity=1)
  headers.set("authorization", "Bearer token")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers~,
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let _ = exporter.export_spans([test_span()])
  assert_eq(mock.headers[0].get("authorization"), Some("Bearer token"))
}

///|
test "configured_content_type_is_replaced_case_insensitively" {
  let mock = mock_transport(200)
  let headers : Map[String, String] = Map([], capacity=1)
  headers.set("Content-Type", "text/plain")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers~,
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let _ = exporter.export_spans([test_span()])
  assert_eq(
    mock.headers[0].get("content-type"),
    Some("application/x-protobuf"),
  )
  assert_eq(mock.headers[0].get("Content-Type"), None)
}

///|
test "export_empty_span_list_skips_transport" {
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(),
    mock.as_transport(),
  )
  let result = exporter.export_spans([])
  assert_true(result.is_success())
  assert_eq(mock.urls.length(), 0)
}

///|
test "export_non_retryable_failure" {
  let mock = mock_transport(500)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318", max_retries=3),
    mock.as_transport(),
  )
  let result = exporter.export_spans([test_span()])
  assert_false(result.is_success())
  assert_eq(mock.urls.length(), 1)
}

///|
test "export_retries_retryable_status" {
  let mock = mock_transport(200)
  mock.responses.push(503)
  mock.responses.push(503)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318", max_retries=3),
    mock.as_transport(),
  )
  let result = exporter.export_spans([test_span()])
  assert_true(result.is_success())
  assert_eq(mock.urls.length(), 3)
}

///|
test "export_gives_up_after_max_retries" {
  let mock = mock_transport(503)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318", max_retries=2),
    mock.as_transport(),
  )
  let result = exporter.export_spans([test_span()])
  assert_false(result.is_success())
  assert_eq(mock.urls.length(), 3)
}

///|
test "export_rejects_unsupported_compression" {
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(
      endpoint="http://collector:4318",
      compression="gzip",
    ),
    mock.as_transport(),
  )
  let result = exporter.export_spans([test_span()])
  assert_false(result.is_success())
  assert_eq(mock.urls.length(), 0)
}

///|
test "exporter_config_accessor" {
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318"),
    mock_transport(200).as_transport(),
  )
  assert_eq(exporter.config().endpoint, "http://collector:4318")
  assert_eq(exporter.config().timeout_millis, 10000)
}

///|
test "config_from_env" {
  @env.set_env_var("OTEL_EXPORTER_OTLP_ENDPOINT", "http://env-collector:4318")
  @env.set_env_var("OTEL_EXPORTER_OTLP_HEADERS", "x-key=abc, x-other = def")
  @env.set_env_var("OTEL_EXPORTER_OTLP_TIMEOUT", "2500")
  let config = @otlp.OtlpHttpConfig::from_env()
  assert_eq(config.endpoint, "http://env-collector:4318")
  assert_eq(config.headers.get("x-key"), Some("abc"))
  assert_eq(config.headers.get("x-other"), Some("def"))
  assert_eq(config.timeout_millis, 2500)
  assert_eq(config.traces_url(), "http://env-collector:4318/v1/traces")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_ENDPOINT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_HEADERS")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TIMEOUT")
}

///|
test "config_from_env_defaults" {
  let config = @otlp.OtlpHttpConfig::from_env()
  assert_eq(config.endpoint, "http://localhost:4318")
  assert_eq(config.compression, "none")
  assert_eq(config.timeout_millis, 10000)
}

///|
test "negative_max_retries_is_clamped_to_zero" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    max_retries=-4,
  )
  assert_eq(config.max_retries, 0)
}

///|
test "negative_max_retries_still_exports_once" {
  let mock = mock_transport(500)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318", max_retries=-4),
    mock.as_transport(),
  )
  let result = exporter.export_spans([test_span()])
  assert_false(result.is_success())
  assert_eq(mock.urls.length(), 1)
}

///|
test "negative_max_retries_on_direct_config_still_exports_once" {
  let config : @otlp.OtlpHttpConfig = {
    endpoint: "http://collector:4318",
    traces_endpoint: None,
    headers: Map([]),
    timeout_millis: 10000,
    compression: "none",
    protocol: @otlp.OTLP_HTTP_PROTOBUF_PROTOCOL,
    max_retries: -4,
  }
  let mock = mock_transport(500)
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let result = exporter.export_spans([test_span()])
  assert_false(result.is_success())
  assert_eq(mock.urls.length(), 1)
}

///|
test "configured_headers_are_deduplicated_case_insensitively" {
  let mock = mock_transport(200)
  let headers : Map[String, String] = Map([])
  headers.set("X-Dup", "1")
  headers.set("x-dup", "2")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers~,
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let _ = exporter.export_spans([test_span()])
  let mut count = 0
  let mut value = ""
  for key, header_value in mock.headers[0] {
    if key.to_lower() == "x-dup" {
      count = count + 1
      value = header_value
    }
  }
  assert_eq(count, 1)
  assert_eq(value, "2")
}

///|
test "shutdown_rejects_further_exports_without_calling_transport" {
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318"),
    mock.as_transport(),
  )
  assert_false(exporter.is_shutdown())
  exporter.shutdown()
  assert_true(exporter.is_shutdown())
  let result = exporter.export_spans([test_span()])
  assert_eq(
    result,
    @sdk.ExportFailure("OTLP exporter is shut down"),
  )
  assert_eq(mock.urls.length(), 0)
}

///|
test "shutdown_rejects_even_an_empty_batch" {
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318"),
    mock.as_transport(),
  )
  exporter.shutdown()
  let result = exporter.export_spans([])
  assert_false(result.is_success())
  assert_eq(mock.urls.length(), 0)
}

///|
test "shutdown_is_idempotent" {
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318"),
    mock.as_transport(),
  )
  exporter.shutdown()
  exporter.shutdown()
  assert_true(exporter.is_shutdown())
  assert_eq(mock.urls.length(), 0)
}
