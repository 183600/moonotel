// A network-path reference (`//authority/path`) has an authority even though
// it has no scheme. Its userinfo must never leak into `url.path`, and the
// recorded path must be the path component only.

///|
test "split_url_path_query_strips_a_network_path_authority" {
  assert_eq(
    split_url_path_query("//user:pass@example.com/path?q=1"),
    ("/path", "q=1"),
  )
  assert_eq(
    split_url_path_query("//user@[2001:db8::1]:8080/a/b?x=1"),
    ("/a/b", "x=1"),
  )
  assert_eq(split_url_path_query("//example.com"), ("", ""))
  assert_eq(split_url_path_query("//example.com?q=1"), ("", "q=1"))
  assert_eq(split_url_path_query("//example.com#frag"), ("", ""))
  assert_eq(split_url_path_query("///path"), ("/path", ""))
}
