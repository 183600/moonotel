// A batch made only of spans with malformed live IDs has nothing to encode, so
// the exporter must not issue an empty OTLP request.

///|
test "exporter_skips_transport_when_all_spans_have_malformed_ids" {
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318"),
    mock.as_transport(),
  )
  let result = exporter.export_spans([short_id_span("short")])
  assert_true(result.is_success())
  assert_eq(mock.urls.length(), 0)
}

///|
test "json_exporter_skips_transport_when_all_spans_have_malformed_ids" {
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(
      endpoint="http://collector:4318",
      protocol=@otlp.OTLP_HTTP_JSON_PROTOCOL,
    ),
    mock.as_transport(),
  )
  let result = exporter.export_spans([short_id_span("short")])
  assert_true(result.is_success())
  assert_eq(mock.urls.length(), 0)
}
