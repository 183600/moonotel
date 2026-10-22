// White-box test: the async request-header builder must not forward configured
// body-framing fields, which the HTTP client sets from the actual body.

///|
test "request_headers_drop_configured_body_framing" {
  let configured : Map[String, String] = Map([], capacity=3)
  configured.set("Content-Length", "0")
  configured.set("Transfer-Encoding", "chunked")
  configured.set("X-Custom", "kept")
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://127.0.0.1:4318",
    headers=configured,
  )
  let headers = request_headers(config, false)
  assert_eq(headers.get(@http.CaseInsensitiveString("content-length")), None)
  assert_eq(headers.get(@http.CaseInsensitiveString("transfer-encoding")), None)
  assert_eq(
    headers.get(@http.CaseInsensitiveString("x-custom")),
    Some("kept"),
  )
}
