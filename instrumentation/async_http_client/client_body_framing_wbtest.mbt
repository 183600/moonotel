// Header capture must describe the body-framing header the async HTTP client
// actually writes: an empty request body has no framing field (the header
// block is terminated by a bare CRLF), while a non-empty body is sent with
// chunked framing. A caller's persistent `Content-Length` is discarded by the
// transport, so it must not be reported either.

///|
test "wire_request_headers_reports_no_framing_for_an_empty_body" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("X-Test"), "1"),
    (@http.CaseInsensitiveString("Content-Length"), "3"),
    (@http.CaseInsensitiveString("Transfer-Encoding"), "chunked"),
  ])
  let wire = wire_request_headers(headers, 0)
  assert_eq(
    wire.get(@http.CaseInsensitiveString("content-length")),
    None,
  )
  assert_eq(
    wire.get(@http.CaseInsensitiveString("transfer-encoding")),
    None,
  )
  assert_eq(wire.get(@http.CaseInsensitiveString("x-test")), Some("1"))
}

///|
test "wire_request_headers_reports_chunked_body_framing" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "3"),
  ])
  let wire = wire_request_headers(headers, 3)
  assert_eq(
    wire.get(@http.CaseInsensitiveString("content-length")),
    None,
  )
  assert_eq(
    wire.get(@http.CaseInsensitiveString("transfer-encoding")),
    Some("chunked"),
  )
}
