// Blackbox tests for case-insensitive OTLP enum values and header names.

///|
fn clear_enum_case_env() -> Unit {
  @env.unset_env_var("OTEL_EXPORTER_OTLP_ENDPOINT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_HEADERS")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_HEADERS")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_COMPRESSION")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_COMPRESSION")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_PROTOCOL")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_PROTOCOL")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TIMEOUT")
  @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT")
}

///|
test "otlp enum environment values are case-insensitive" {
  clear_enum_case_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_PROTOCOL", "HTTP/JSON")
  @env.set_env_var("OTEL_EXPORTER_OTLP_TRACES_COMPRESSION", "GZIP")
  let config = @otlp.OtlpHttpConfig::from_env()
  clear_enum_case_env()
  assert_eq(config.protocol, "http/json")
  assert_eq(config.compression, "gzip")
}

///|
test "otlp enum constructor arguments are normalized" {
  let config = @otlp.OtlpHttpConfig::new(
    protocol="HTTP/Protobuf",
    compression="NONE",
  )
  assert_eq(config.protocol, "http/protobuf")
  assert_eq(config.compression, "none")
}

///|
test "protocol helpers are case-insensitive" {
  assert_true(@otlp.is_supported_protocol("HTTP/PROTOBUF"))
  assert_true(@otlp.is_supported_protocol(" http/json "))
  assert_false(@otlp.is_supported_protocol("GRPC"))
  assert_eq(
    @otlp.content_type_for_protocol("HTTP/JSON"),
    "application/json",
  )
  assert_eq(
    @otlp.content_type_for_protocol("HTTP/PROTOBUF"),
    "application/x-protobuf",
  )
}

///|
test "traces headers override generic headers case-insensitively" {
  clear_enum_case_env()
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_HEADERS", "X-Token=generic,shared=1",
  )
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_TRACES_HEADERS", "x-token=specific,SHARED=2",
  )
  let config = @otlp.OtlpHttpConfig::from_env()
  clear_enum_case_env()
  assert_eq(config.headers.length(), 2)
  assert_eq(config.headers.get("x-token"), Some("specific"))
  assert_eq(config.headers.get("X-Token"), None)
  assert_eq(config.headers.get("SHARED"), Some("2"))
  assert_eq(config.headers.get("shared"), None)
}

///|
test "duplicate header names inside one variable are collapsed" {
  clear_enum_case_env()
  @env.set_env_var("OTEL_EXPORTER_OTLP_HEADERS", "X-Dup=1,x-dup=2")
  let config = @otlp.OtlpHttpConfig::from_env()
  clear_enum_case_env()
  assert_eq(config.headers.length(), 1)
  assert_eq(config.headers.get("x-dup"), Some("2"))
}

///|
fn enum_case_span() -> @sdk.SpanData {
  let trace_id = Array::make(16, 3)
  let span_id = Array::make(8, 5)
  let context = @api.span_context(trace_id, span_id, @api.TRACE_FLAGS_SAMPLED)
  {
    name: "enum-case",
    span_context: context,
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
    scope_name: "enum-case",
    scope_version: "",
  }
}

///|
test "mixed-case config literals still select the right encoding" {
  let base = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318")
  let config : @otlp.OtlpHttpConfig = {
    ..base,
    protocol: "HTTP/JSON",
    compression: "NONE",
  }
  let seen : Ref[Map[String, String]?] = Ref(None)
  let send : @otlp.Transport = fn(_url, headers, _body) {
    seen.val = Some(headers)
    { status_code: 200, body: b"", }
  }
  let exporter = @otlp.OtlpHttpExporter::new(config, send)
  let result = exporter.export_spans([enum_case_span()])
  assert_true(result.is_success())
  match seen.val {
    Some(headers) =>
      assert_eq(headers.get("content-type"), Some("application/json"))
    None => fail("expected the transport to be called")
  }
}
