// Constructing an exporter snapshots its configuration, so mutating the
// caller's header map (or the config value passed in) afterwards cannot change
// the exporter or a later request.

///|
test "exporter snapshots the config header map at construction" {
  let headers : Map[String, String] = Map([("authorization", "Bearer token")])
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers~,
  )
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  headers.set("authorization", "changed")
  config.headers.set("x-added-later", "1")
  assert_eq(
    exporter.config().headers.get("authorization"),
    Some("Bearer token"),
  )
  assert_eq(exporter.config().headers.get("x-added-later"), None)
  assert_true(exporter.export_spans([test_span()]).is_success())
  assert_eq(mock.headers[0].get("authorization"), Some("Bearer token"))
  assert_eq(mock.headers[0].get("x-added-later"), None)
}
