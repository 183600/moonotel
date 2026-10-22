// The exporter's transport owns request body framing. Configured
// `Content-Length` / `Transfer-Encoding` values must not be forwarded because
// they can contradict the body length actually sent.

///|
test "configured_body_framing_headers_are_not_sent" {
  let mock = mock_transport(200)
  let headers : Map[String, String] = Map([], capacity=3)
  headers.set("Content-Length", "0")
  headers.set("Transfer-Encoding", "chunked")
  headers.set("X-Custom", "kept")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers~,
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  let result = exporter.export_spans([test_span()])
  assert_true(result.is_success())
  assert_eq(mock.headers[0].get("content-length"), None)
  assert_eq(mock.headers[0].get("transfer-encoding"), None)
  assert_eq(mock.headers[0].get("X-Custom"), Some("kept"))
}
