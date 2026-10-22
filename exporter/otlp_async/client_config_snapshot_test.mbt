// Constructing an async exporter snapshots its configuration, so mutating the
// caller's config header map afterwards cannot change the exporter or its
// cached request headers.

///|
test "async exporter snapshots the config header map at construction" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers=Map([("authorization", "Bearer token")]),
  )
  let exporter = @otlp_async.OtlpHttpAsyncExporter::new(config)
  config.headers.set("authorization", "changed")
  config.headers.set("x-added-later", "1")
  assert_eq(
    exporter.config().headers.get("authorization"),
    Some("Bearer token"),
  )
  assert_eq(exporter.config().headers.get("x-added-later"), None)
  assert_eq(
    exporter.headers.get(@http.CaseInsensitiveString("authorization")),
    Some("Bearer token"),
  )
  assert_true(
    exporter.headers.get(@http.CaseInsensitiveString("x-added-later")) is None,
  )
}
