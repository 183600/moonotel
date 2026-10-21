// White-box tests: a `://` sequence only starts an authority after a valid
// URL scheme. Otherwise it belongs to a relative path or query.

///|
test "split_url_path_query_ignores_invalid_scheme_separators" {
  assert_eq(
    split_url_path_query("/foo://user:pass@host?x=1"),
    ("/foo://user:pass@host", "x=1"),
  )
  assert_eq(
    split_url_path_query("example.com?next=http://user:pass@host"),
    ("example.com", "next=http://user:pass@host"),
  )
  assert_eq(
    split_url_path_query("1http://example.com/x?q=1"),
    ("1http://example.com/x", "q=1"),
  )
}

///|
test "split_url_path_query_handles_valid_schemes" {
  assert_eq(
    split_url_path_query("https://example.com/a://b?q=1"),
    ("/a://b", "q=1"),
  )
  assert_eq(
    split_url_path_query("https://user:pass@example.com/x#frag"),
    ("/x", ""),
  )
}
