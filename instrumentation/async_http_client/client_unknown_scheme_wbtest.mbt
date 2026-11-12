// White-box coverage for the client attributes and CONNECT target of a URL
// whose scheme has no known default port.

///|
test "unknown scheme records an address without a fabricated port" {
  let attributes = initial_client_attributes(
    "ftp://example.com/file",
    @http.RequestMethod::Get,
    0,
  )
  assert_eq(
    attributes.get(@sdk.URL_SCHEME),
    Some(@sdk.StringValue("ftp")),
  )
  assert_eq(
    attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("example.com")),
  )
  assert_eq(attributes.get(@sdk.SERVER_PORT), None)
}

///|
test "unknown scheme records an explicit port" {
  let attributes = initial_client_attributes(
    "ftp://example.com:21/file",
    @http.RequestMethod::Get,
    0,
  )
  assert_eq(
    attributes.get(@sdk.SERVER_PORT),
    Some(@sdk.IntValue(21)),
  )
}

///|
test "connect target needs a known default port" {
  assert_eq(connect_authority_target("ftp://example.com/file"), None)
  assert_eq(
    connect_authority_target("ftp://example.com:21/file"),
    Some("example.com:21"),
  )
  assert_eq(
    connect_authority_target("https://example.com/file"),
    Some("example.com:443"),
  )
}
