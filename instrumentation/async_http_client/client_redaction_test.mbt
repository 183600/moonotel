// Tests for `redact_url`, which keeps credentials out of the `url.full`
// span attribute as required by the HTTP semantic conventions.

test "redact_url_removes_user_and_password" {
  assert_eq(
    @async_http_client.redact_url("http://user:pass@example.com/path"),
    "http://example.com/path",
  )
  assert_eq(@async_http_client.redact_url("https://user@example.com"), "https://example.com")
  assert_eq(
    @async_http_client.redact_url("http://user:pass@example.com?q=1#f"),
    "http://example.com?q=1#f",
  )
  assert_eq(
    @async_http_client.redact_url("http://user:pass@[::1]:8080/x"),
    "http://[::1]:8080/x",
  )
  assert_eq(
    @async_http_client.redact_url("http://user:p%40ss@host.test:9000/"),
    "http://host.test:9000/",
  )
}

test "redact_url_leaves_urls_without_userinfo_unchanged" {
  assert_eq(
    @async_http_client.redact_url("http://example.com/path"),
    "http://example.com/path",
  )
  assert_eq(
    @async_http_client.redact_url("http://example.com:8080/path?x=1"),
    "http://example.com:8080/path?x=1",
  )
  assert_eq(@async_http_client.redact_url("example.com/path"), "example.com/path")
  assert_eq(@async_http_client.redact_url(""), "")
}

test "redact_url_preserves_at_signs_outside_the_authority" {
  assert_eq(
    @async_http_client.redact_url("http://example.com/a@b"),
    "http://example.com/a@b",
  )
  assert_eq(
    @async_http_client.redact_url("http://example.com?mail=me@x"),
    "http://example.com?mail=me@x",
  )
  assert_eq(
    @async_http_client.redact_url("http://example.com#a@b"),
    "http://example.com#a@b",
  )
}

