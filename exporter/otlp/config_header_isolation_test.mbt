// `OtlpHttpConfig::new` owns its header map, so later mutations of the
// caller's map cannot change an exporter built from the config.

///|
test "config_new_copies_the_header_map" {
  let headers : Map[String, String] = Map([("authorization", "Bearer token")])
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers~,
  )
  headers.set("x-added-later", "1")
  headers.set("authorization", "changed")
  assert_eq(config.headers.get("authorization"), Some("Bearer token"))
  assert_eq(config.headers.get("x-added-later"), None)
}

///|
test "exporter_config_accessor_returns_an_isolated_header_snapshot" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers=Map([("authorization", "Bearer token")]),
  )
  let exporter = @otlp.OtlpHttpExporter::new(config, mock_transport(200).as_transport())
  let returned = exporter.config()
  returned.headers.set("authorization", "changed")
  returned.headers.set("x-added-later", "1")
  assert_eq(
    exporter.config().headers.get("authorization"),
    Some("Bearer token"),
  )
  assert_eq(exporter.config().headers.get("x-added-later"), None)
}

///|
test "exporter_built_from_config_keeps_the_header_snapshot" {
  let headers : Map[String, String] = Map([("authorization", "Bearer token")])
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers~,
  )
  let mock = mock_transport(200)
  let exporter = @otlp.OtlpHttpExporter::new(config, mock.as_transport())
  headers.set("authorization", "changed")
  headers.set("x-added-later", "1")
  assert_true(exporter.export_spans([test_span()]).is_success())
  assert_eq(
    mock.headers[0].get("authorization"),
    Some("Bearer token"),
  )
  assert_eq(mock.headers[0].get("x-added-later"), None)
}
