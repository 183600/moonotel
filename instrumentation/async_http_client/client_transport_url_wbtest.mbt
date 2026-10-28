// White-box tests for the URL forms that the async HTTP transport cannot
// accept directly even though they are valid RFC 3986 references.

///|
test "normalize_url_for_transport_lowercases_http_schemes" {
  assert_eq(
    normalize_url_for_transport("HTTP://example.com:/x"),
    "http://example.com/x",
  )
  assert_eq(
    normalize_url_for_transport("HtTpS://example.com:/x?q=1#frag"),
    "https://example.com/x?q=1#frag",
  )
}

///|
test "normalize_url_for_transport_removes_an_empty_port" {
  assert_eq(
    normalize_url_for_transport("http://example.com:"),
    "http://example.com",
  )
  assert_eq(
    normalize_url_for_transport("http://example.com:/x"),
    "http://example.com/x",
  )
  assert_eq(
    normalize_url_for_transport("http://example.com:?q=1"),
    "http://example.com?q=1",
  )
  assert_eq(
    normalize_url_for_transport("http://example.com:#frag"),
    "http://example.com#frag",
  )
  assert_eq(
    normalize_url_for_transport("http://[::1]:/x"),
    "http://[::1]/x",
  )
  assert_eq(
    normalize_url_for_transport("http://user:pass@example.com:/x"),
    "http://user:pass@example.com/x",
  )
}

///|
test "normalize_url_for_transport_leaves_non_empty_and_malformed_ports" {
  for url in [
    "http://example.com:80/x",
    "http://example.com:8080/x",
    "http://example.com:80:/x",
    "http://example.com::/x",
    "http://[::1]:8080/x",
    "http://[::1]:80:/x",
  ] {
    assert_eq(normalize_url_for_transport(url), url)
  }
}

///|
test "normalize_url_for_transport_leaves_other_schemes_and_relative_urls" {
  for url in [
    "FTP://example.com:/x",
    "ftp://example.com:/x",
    "http+unix://sock:/x",
    "//example.com:/x",
    "/foo://example.com:/x",
    "example.com:/x",
  ] {
    assert_eq(normalize_url_for_transport(url), url)
  }
}

///|
test "split_url_for_transport_uses_a_normalized_empty_port" {
  assert_eq(
    split_url_for_transport("http://example.com:/x?q=1"),
    ("http://example.com", "/x?q=1"),
  )
  assert_eq(
    split_url_for_transport("https://[::1]:/"),
    ("https://[::1]", "/"),
  )
}
