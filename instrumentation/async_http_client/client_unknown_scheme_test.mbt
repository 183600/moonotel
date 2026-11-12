// `split_url` must not invent an HTTP default port for a scheme whose default
// port is unknown. Explicit ports still work for such schemes.

///|
test "split_url only defaults ports for http and https" {
  assert_eq(
    @async_http_client.split_url("ftp://example.com/file"),
    ("example.com", -1),
  )
  assert_eq(
    @async_http_client.split_url("ftp://example.com:21/file"),
    ("example.com", 21),
  )
  assert_eq(
    @async_http_client.split_url("ftp://[2001:db8::1]/file"),
    ("[2001:db8::1]", -1),
  )
  assert_eq(
    @async_http_client.split_url("ftp://[2001:db8::1]:2121/file"),
    ("[2001:db8::1]", 2121),
  )
  assert_eq(
    @async_http_client.split_url("http+unix://socket"),
    ("socket", -1),
  )
}
