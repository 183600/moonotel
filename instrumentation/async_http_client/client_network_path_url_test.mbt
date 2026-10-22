
///|
test "split_url_parses_a_network_path_authority" {
  assert_eq(
    @async_http_client.split_url("//example.com:8080/path"),
    ("example.com", 8080),
  )
  assert_eq(
    @async_http_client.split_url("//user:pass@example.com/path"),
    ("example.com", 80),
  )
  assert_eq(
    @async_http_client.split_url("//user@[2001:db8::1]:9090/a/b"),
    ("[2001:db8::1]", 9090),
  )
  // A network-path reference still has no scheme, so the client
  // instrumentation must not treat it as an absolute URL when recording
  // `url.scheme` or the `server.*` attributes.
  assert_eq(@async_http_client.split_scheme("//example.com/path"), "")
  assert_eq(@async_http_client.split_url("///path"), ("", 80))
}
