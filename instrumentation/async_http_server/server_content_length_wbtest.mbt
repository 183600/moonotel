// The transport parses response `Content-Length` with the lenient integer
// parser after trimming, so header capture must not invent chunked framing
// for values such as `+5` that the transport accepts and uses.

///|
test "wire_response_headers mirrors lenient content-length parsing" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "+5"),
  ])
  let wire = wire_response_headers(headers, @http.Get, 200, true)
  assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), Some("+5"))
  assert_eq(wire.get(@http.CaseInsensitiveString("transfer-encoding")), None)
}

///|
test "wire_response_headers accepts content-length trimmed by the transport" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "5\r\n"),
  ])
  let wire = wire_response_headers(headers, @http.Get, 200, true)
  assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), Some("5"))
  assert_eq(wire.get(@http.CaseInsensitiveString("transfer-encoding")), None)
}

///|
test "wire_response_headers rejects negative content-length" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "-1"),
  ])
  let wire = wire_response_headers(headers, @http.Get, 200, true)
  assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), None)
  assert_eq(
    wire.get(@http.CaseInsensitiveString("transfer-encoding")),
    Some("chunked"),
  )
  let empty_wire = wire_response_headers(headers, @http.Get, 200, false)
  assert_eq(
    empty_wire.get(@http.CaseInsensitiveString("content-length")),
    Some("0"),
  )
}

///|
test "wire_response_headers rejects malformed content-length" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "not-a-number"),
  ])
  let wire = wire_response_headers(headers, @http.Get, 200, true)
  assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), None)
  assert_eq(
    wire.get(@http.CaseInsensitiveString("transfer-encoding")),
    Some("chunked"),
  )
}

///|
test "wire_response_headers drops content-length on 1xx and 204 responses" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "7"),
  ])
  for status_code in [199, 204] {
    let wire = wire_response_headers(headers, @http.Get, status_code, false)
    assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), None)
  }
  let not_modified = wire_response_headers(headers, @http.Get, 304, false)
  assert_eq(
    not_modified.get(@http.CaseInsensitiveString("content-length")),
    Some("7"),
  )
}
