// The async exporter validates headers again when building the request, so a
// config assembled directly from the public fields can never smuggle a
// malformed name or a CR/LF-injected value into the HTTP client.

///|
test "request_headers_drops_invalid_headers_from_a_direct_config" {
  let base = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318")
  let config : @otlp.OtlpHttpConfig = {
    ..base,
    headers: Map([
      ("bad name", "v"),
      ("x-evil", "a\r\nb"),
      ("x-ok", "v"),
    ]),
  }
  let headers = request_headers(config, false)
  assert_eq(headers.get(@http.CaseInsensitiveString("bad name")), None)
  assert_eq(headers.get(@http.CaseInsensitiveString("x-evil")), None)
  assert_eq(headers.get(@http.CaseInsensitiveString("x-ok")), Some("v"))
  // The protocol headers are always present and cannot be overridden.
  assert_eq(
    headers.get(@http.CaseInsensitiveString("content-type")),
    Some("application/x-protobuf"),
  )
  assert_eq(
    headers.get(@http.CaseInsensitiveString("accept")),
    Some("application/x-protobuf"),
  )
}
