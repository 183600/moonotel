// Regression test: response decompression is owned by the synchronous
// transport, just like in the async exporter. A configured `Accept-Encoding`
// would ask the collector for a compressed response that this exporter cannot
// decode, so it must not be forwarded.

///|
test "configured_accept_encoding_is_not_sent" {
  let mock = mock_transport(200)
  let headers : Map[String, String] = Map([], capacity=3)
  headers.set("Accept-Encoding", "gzip")
  headers.set("accept-encoding", "identity")
  headers.set("X-Custom", "kept")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers~,
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let result = exporter.export_spans([test_span()])
  assert_true(result.is_success())
  assert_eq(mock.headers[0].get("accept-encoding"), None)
  assert_eq(mock.headers[0].get("Accept-Encoding"), None)
  assert_eq(mock.headers[0].get("X-Custom"), Some("kept"))
}
