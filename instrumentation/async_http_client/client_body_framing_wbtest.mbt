// Header capture must describe the body-framing header the async HTTP client
// actually writes: an empty request body has no framing field (the header
// block is terminated by a bare CRLF), a non-empty body without a usable
// `Content-Length` is sent with chunked framing, and a caller-supplied
// `Content-Length` selects fixed-length framing while `Transfer-Encoding` is
// dropped.

///|
test "wire_request_headers_reports_no_framing_for_an_empty_body" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("X-Test"), "1"),
    (@http.CaseInsensitiveString("Transfer-Encoding"), "chunked"),
  ])
  let wire = wire_request_headers(headers, 0)
  assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), None)
  assert_eq(wire.get(@http.CaseInsensitiveString("transfer-encoding")), None)
  assert_eq(wire.get(@http.CaseInsensitiveString("x-test")), Some("1"))
}

///|
test "wire_request_headers_reports_chunked_body_framing" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Transfer-Encoding"), "gzip"),
  ])
  let wire = wire_request_headers(headers, 3)
  assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), None)
  assert_eq(
    wire.get(@http.CaseInsensitiveString("transfer-encoding")),
    Some("chunked"),
  )
}

///|
test "wire_request_headers_preserves_a_caller_supplied_content_length" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "3"),
    (@http.CaseInsensitiveString("Transfer-Encoding"), "gzip"),
  ])
  let wire = wire_request_headers(headers, 3)
  assert_eq(
    wire.get(@http.CaseInsensitiveString("content-length")),
    Some("3"),
  )
  assert_eq(wire.get(@http.CaseInsensitiveString("transfer-encoding")), None)
}

///|
test "wire_request_headers_ignores_an_unusable_content_length" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "not-a-number"),
  ])
  let wire = wire_request_headers(headers, 3)
  assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), None)
  assert_eq(
    wire.get(@http.CaseInsensitiveString("transfer-encoding")),
    Some("chunked"),
  )
}
