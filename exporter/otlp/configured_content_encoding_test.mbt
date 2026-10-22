// Regression test: the synchronous exporter sends uncompressed bodies only,
// so a user-configured `Content-Encoding` must not be forwarded.

///|
test "configured_content_encoding_is_not_sent" {
  let mock = mock_transport(200)
  let headers : Map[String, String] = Map([], capacity=1)
  headers.set("Content-Encoding", "gzip")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers~,
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let _ = exporter.export_spans([test_span()])
  assert_eq(mock.headers[0].get("content-encoding"), None)
  assert_eq(mock.headers[0].get("Content-Encoding"), None)
}
