// Malformed OTLP headers must never reach the transport. Header names are
// HTTP tokens and header values cannot contain CR, LF or other control
// characters; invalid environment or programmatic entries are dropped.

///|
test "env_headers_reject_invalid_names_and_values" {
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_HEADERS",
    "bad name=1,good=2,x-evil=a\r\nInjected: 1,x-tab=a\tb",
  )
  let config = @otlp.OtlpHttpConfig::from_env()
  @env.unset_env_var("OTEL_EXPORTER_OTLP_HEADERS")
  assert_eq(config.headers.get("bad name"), None)
  assert_eq(config.headers.get("x-evil"), None)
  assert_eq(config.headers.get("good"), Some("2"))
  // HTAB is allowed in a field value.
  assert_eq(config.headers.get("x-tab"), Some("a\tb"))
}

///|
test "config_constructor_drops_invalid_headers" {
  let config = @otlp.OtlpHttpConfig::new(
    headers=Map([
      ("bad name", "v"),
      ("x-evil", "a\r\nb"),
      ("x-good", "v"),
    ]),
  )
  assert_eq(config.headers.length(), 1)
  assert_eq(config.headers.get("x-good"), Some("v"))
}

///|
test "with_headers_drops_invalid_headers" {
  let base = @otlp.OtlpHttpConfig::new(headers=Map([("old", "1")]))
  let config = base.with_headers(
    Map([
      ("bad:name", "v"),
      ("x-evil", "a\nb"),
      ("new", "2"),
    ]),
  )
  assert_eq(config.headers.get("old"), Some("1"))
  assert_eq(config.headers.get("new"), Some("2"))
  assert_eq(config.headers.get("bad:name"), None)
  assert_eq(config.headers.get("x-evil"), None)
}

///|
test "exporter_revalidates_headers_from_a_directly_built_config" {
  let mock = mock_transport(200)
  let base = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318")
  let config : @otlp.OtlpHttpConfig = {
    ..base,
    headers: Map([
      ("bad name", "v"),
      ("x-evil", "a\r\nb"),
      ("x-ok", "v"),
    ]),
  }
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  assert_true(exporter.export_spans([test_span()]).is_success())
  assert_eq(mock.headers[0].get("bad name"), None)
  assert_eq(mock.headers[0].get("x-evil"), None)
  assert_eq(mock.headers[0].get("x-ok"), Some("v"))
}

///|
test "header_validation_accepts_token_names_and_unicode_values" {
  assert_true(@otlp.is_valid_http_header_name("x-token_1.2~"))
  assert_false(@otlp.is_valid_http_header_name(""))
  assert_false(@otlp.is_valid_http_header_name("x token"))
  assert_false(@otlp.is_valid_http_header_name("x:token"))
  assert_false(@otlp.is_valid_http_header_name("é"))
  assert_true(@otlp.is_valid_http_header_value("café ☕"))
  assert_true(@otlp.is_valid_http_header_value("a\tb"))
  assert_false(@otlp.is_valid_http_header_value("a\r\nb"))
  assert_false(@otlp.is_valid_http_header_value("a\u{0}b"))
}

///|
test "header_validation_rejects_unpaired_utf16_surrogates" {
  let high = String::from_array([(0xD800).unsafe_to_char()])
  let low = String::from_array([(0xDC00).unsafe_to_char()])
  let pair = String::from_array(
    [(0xD83D).unsafe_to_char(), (0xDE00).unsafe_to_char()],
  )
  assert_false(@otlp.is_valid_http_header_value(high))
  assert_false(@otlp.is_valid_http_header_value(low))
  assert_false(@otlp.is_valid_http_header_value("a" + high + "b"))
  assert_false(@otlp.is_valid_http_header_value(high + low + high))
  assert_true(@otlp.is_valid_http_header_value(pair))
  assert_true(@otlp.is_valid_http_header_value("a" + pair + "b"))

  let config = @otlp.OtlpHttpConfig::new(
    headers=Map([("x-bad", high), ("x-good", pair)]),
  )
  assert_eq(config.headers.get("x-bad"), None)
  assert_eq(config.headers.get("x-good"), Some(pair))
}
