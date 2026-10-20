// Regression tests: credentials are only removed from URLs that actually have
// a valid scheme and therefore an authority component.

///|
test "redact_url_ignores_colon_slashes_outside_a_valid_scheme" {
  assert_eq(
    @async_http_client.redact_url("/foo://user:pass@host"),
    "/foo://user:pass@host",
  )
  assert_eq(
    @async_http_client.redact_url("1http://user:pass@host"),
    "1http://user:pass@host",
  )
  assert_eq(
    @async_http_client.redact_url("ht^tp://user:pass@host"),
    "ht^tp://user:pass@host",
  )
  assert_eq(
    @async_http_client.redact_url("example.com/http://user:pass@host"),
    "example.com/http://user:pass@host",
  )
}

///|
test "redact_url_accepts_all_valid_scheme_characters" {
  assert_eq(
    @async_http_client.redact_url("a+b.c-d://user:pass@host/x"),
    "a+b.c-d://host/x",
  )
  assert_eq(
    @async_http_client.redact_url("HTTP://user:pass@host"),
    "HTTP://host",
  )
}
