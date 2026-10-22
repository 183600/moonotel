// The injected transport gets a copy of the exporter's headers, so a transport
// that normalizes or augments them cannot corrupt later retries or exports.

///|
test "transport_header_mutation_does_not_leak_between_exports" {
  let seen : Array[Map[String, String]] = []
  let transport : @otlp.Transport = fn(_url, headers, _body) {
    seen.push(headers.copy())
    headers.remove("content-type")
    headers.set("x-transport-mutated", "1")
    { status_code: 200, body: b"", }
  }
  let exporter = @otlp.OtlpHttpExporter::new(
    @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318"),
    transport,
  )
  assert_true(exporter.export_spans([test_span()]).is_success())
  assert_true(exporter.export_spans([test_span()]).is_success())
  assert_eq(seen.length(), 2)
  for headers in seen {
    assert_eq(
      headers.get("content-type"),
      Some("application/x-protobuf"),
    )
    assert_eq(headers.get("x-transport-mutated"), None)
  }
}
