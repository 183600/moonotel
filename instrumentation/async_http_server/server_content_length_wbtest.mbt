// The transport parses response `Content-Length` with the lenient integer
// parser after trimming, so header capture must not invent chunked framing
// for values such as `+5` that the transport accepts and uses.

///|
test "wire_response_headers mirrors lenient content-length parsing" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "+5"),
  ])
  let wire = wire_response_headers(headers, @http.Get, 200, true)
  assert_eq(
    wire.get(@http.CaseInsensitiveString("content-length")),
    Some("+5"),
  )
  assert_eq(
    wire.get(@http.CaseInsensitiveString("transfer-encoding")),
    None,
  )
}

///|
test "wire_response_headers accepts content-length trimmed by the transport" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "5\r\n"),
  ])
  let wire = wire_response_headers(headers, @http.Get, 200, true)
  assert_eq(
    wire.get(@http.CaseInsensitiveString("content-length")),
    Some("5"),
  )
  assert_eq(
    wire.get(@http.CaseInsensitiveString("transfer-encoding")),
    None,
  )
}
