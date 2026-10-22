// OTLP/HTTP exporters identify themselves with a User-Agent header, as asked
// for by the OTLP exporter specification. An explicitly configured value wins.

///|
fn user_agent_header_count(headers : Map[String, String]) -> Int32 {
  let mut count = 0
  for key, _ in headers {
    if key.to_lower() == "user-agent" {
      count = count + 1
    }
  }
  count
}

///|
fn user_agent_header_value(headers : Map[String, String]) -> String {
  let mut value = ""
  for key, header_value in headers {
    if key.to_lower() == "user-agent" {
      value = header_value
    }
  }
  value
}

///|
test "export_sends_the_default_user_agent" {
  let mock = accept_mock_transport()
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318"),
    mock.as_transport(),
  )
  assert_true(exporter.export_spans([accept_test_span()]).is_success())
  assert_eq(mock.headers.length(), 1)
  assert_eq(user_agent_header_count(mock.headers[0]), 1)
  assert_eq(
    user_agent_header_value(mock.headers[0]),
    "OTel-OTLP-Exporter-MoonBit/" + @sdk.SDK_VERSION,
  )
}

///|
test "configured_user_agent_overrides_the_default_case_insensitively" {
  let mock = accept_mock_transport()
  let headers : Map[String, String] = Map([], capacity=1)
  headers.set("User-Agent", "custom-agent/9.9")
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(
      endpoint="http://collector:4318",
      headers~,
    ),
    mock.as_transport(),
  )
  assert_true(exporter.export_spans([accept_test_span()]).is_success())
  assert_eq(mock.headers.length(), 1)
  assert_eq(user_agent_header_count(mock.headers[0]), 1)
  assert_eq(user_agent_header_value(mock.headers[0]), "custom-agent/9.9")
}

///|
test "configured_user_agent_is_not_duplicated_across_case_variants" {
  let mock = accept_mock_transport()
  let headers : Map[String, String] = Map([], capacity=2)
  headers.set("user-agent", "first/1.0")
  headers.set("USER-AGENT", "second/2.0")
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(
      endpoint="http://collector:4318",
      headers~,
    ),
    mock.as_transport(),
  )
  assert_true(exporter.export_spans([accept_test_span()]).is_success())
  assert_eq(mock.headers.length(), 1)
  assert_eq(user_agent_header_count(mock.headers[0]), 1)
  assert_eq(user_agent_header_value(mock.headers[0]), "second/2.0")
}
