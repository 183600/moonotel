// A config built directly (rather than with `OtlpHttpConfig::new`) may carry
// blank or untrimmed strings. Those boundaries must behave like the values
// passed through the constructor: blank protocol/compression mean the OTLP
// defaults, a blank traces endpoint is unset, and surrounding whitespace is
// not part of a URL.

///|
fn direct_config(
  endpoint : String,
  traces_endpoint : String?,
  headers : Map[String, String],
  timeout_millis : Int32,
  compression : String,
  protocol : String,
  max_retries : Int32,
) -> @otlp.OtlpHttpConfig {
  {
    endpoint,
    traces_endpoint,
    headers,
    timeout_millis,
    compression,
    protocol,
    max_retries,
  }
}

///|
test "direct_config_blank_protocol_and_compression_use_defaults" {
  let mock = mock_transport(200)
  let config = direct_config(
    "http://collector:4318",
    None,
    Map([]),
    10000,
    "  ",
    " \t ",
    0,
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let result = exporter.export_spans([test_span()])
  assert_true(result.is_success())
  assert_eq(mock.urls.length(), 1)
  assert_eq(mock.urls[0], "http://collector:4318/v1/traces")
  assert_eq(
    mock.headers[0].get("content-type"),
    Some("application/x-protobuf"),
  )
  assert_eq(mock.headers[0].get("accept"), Some("application/x-protobuf"))
}

///|
test "direct_config_still_rejects_non_blank_unsupported_values" {
  let protocol_mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    direct_config(
      "http://collector:4318",
      None,
      Map([]),
      10000,
      "none",
      "grpc",
      0,
    ),
    protocol_mock.as_transport(),
  )
  assert_false(exporter.export_spans([test_span()]).is_success())
  assert_eq(protocol_mock.urls.length(), 0)

  let compression_mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    direct_config(
      "http://collector:4318",
      None,
      Map([]),
      10000,
      "gzip",
      @otlp.OTLP_HTTP_PROTOBUF_PROTOCOL,
      0,
    ),
    compression_mock.as_transport(),
  )
  assert_false(exporter.export_spans([test_span()]).is_success())
  assert_eq(compression_mock.urls.length(), 0)
}

///|
test "direct_config_blank_traces_endpoint_falls_back_to_the_base_endpoint" {
  for traces_endpoint in ["", "   ", "\t"] {
    let config = direct_config(
      "http://collector:4318",
      Some(traces_endpoint),
      Map([]),
      10000,
      "none",
      @otlp.OTLP_HTTP_PROTOBUF_PROTOCOL,
      0,
    )
    assert_eq(config.traces_url(), "http://collector:4318/v1/traces")
  }
}

///|
test "direct_config_blank_endpoint_uses_the_default_base_endpoint" {
  let config = direct_config(
    "",
    None,
    Map([]),
    10000,
    "none",
    @otlp.OTLP_HTTP_PROTOBUF_PROTOCOL,
    0,
  )
  assert_eq(config.traces_url(), "http://localhost:4318/v1/traces")
}

///|
test "direct_config_urls_are_trimmed_but_not_rewritten" {
  let generic = direct_config(
    "  http://generic:4318  ",
    None,
    Map([]),
    10000,
    "none",
    @otlp.OTLP_HTTP_PROTOBUF_PROTOCOL,
    0,
  )
  assert_eq(generic.traces_url(), "http://generic:4318/v1/traces")

  let specific = direct_config(
    "http://generic:4318",
    Some("  http://specific:4318/custom/traces  "),
    Map([]),
    10000,
    "none",
    @otlp.OTLP_HTTP_PROTOBUF_PROTOCOL,
    0,
  )
  assert_eq(specific.traces_url(), "http://specific:4318/custom/traces")

  let root = direct_config(
    "http://generic:4318",
    Some("  http://specific:4318  "),
    Map([]),
    10000,
    "none",
    @otlp.OTLP_HTTP_PROTOBUF_PROTOCOL,
    0,
  )
  assert_eq(root.traces_url(), "http://specific:4318/")
}
