// RFC 3986 allows an empty port component, which denotes the scheme's default
// port. The URL splitter must not report it as an invalid explicit port.

///|
test "split_url treats an empty port as the scheme default" {
  assert_eq(
    @async_http_client.split_url("http://example.com:/path"),
    ("example.com", 80),
  )
  assert_eq(
    @async_http_client.split_url("https://example.com:/path"),
    ("example.com", 443),
  )
  assert_eq(
    @async_http_client.split_url("http://[::1]:/path"),
    ("[::1]", 80),
  )
  assert_eq(
    @async_http_client.split_url("https://[2001:db8::1]:/"),
    ("[2001:db8::1]", 443),
  )
}
