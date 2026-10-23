// `traces_url` preserves the configured spelling (including a fragment), but
// the HTTP transport must receive a request URL with the fragment removed, a
// normalized scheme, and a resolvable network-path reference.

///|
test "request_url_strips_fragments_and_keeps_queries" {
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="http://collector:4318/custom#frag",
    ).request_url(),
    "http://collector:4318/custom",
  )
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      endpoint="http://collector:4318/base?token=secret#section",
    ).request_url(),
    "http://collector:4318/base/v1/traces?token=secret",
  )
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="http://collector:4318/custom?x=%23not-a-fragment",
    ).request_url(),
    "http://collector:4318/custom?x=%23not-a-fragment",
  )
}

///|
test "request_url_normalizes_schemes" {
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="HTTP://collector:4318/custom",
    ).request_url(),
    "http://collector:4318/custom",
  )
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="HtTpS://collector:4318/custom#frag",
    ).request_url(),
    "https://collector:4318/custom",
  )
}

///|
test "request_url_resolves_a_network_path_reference" {
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="//collector:4318/custom#frag",
    ).request_url(),
    "http://collector:4318/custom",
  )
  assert_eq(
    @otlp.OtlpHttpConfig::new(traces_endpoint="//collector:4318").request_url(),
    "http://collector:4318/",
  )
}

///|
test "exporter_passes_the_request_url_to_the_transport" {
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="HTTP://collector:4318/custom#frag",
    ),
    mock.as_transport(),
  )
  assert_true(exporter.export_spans([test_span()]).is_success())
  assert_eq(mock.urls, ["http://collector:4318/custom"])
}
