// White-box tests for the authority component of an absolute-form request
// target. The authority decides `server.address`/`server.port` whenever the
// request target is in absolute-form, taking precedence over the Host header.

///|
test "absolute_target_authority_extracts_authority" {
  assert_eq(
    absolute_target_authority("http://backend.internal:8080/items"),
    Some("backend.internal:8080"),
  )
  assert_eq(
    absolute_target_authority("https://example.com/items"),
    Some("example.com"),
  )
  assert_eq(
    absolute_target_authority("HTTP://Example.COM/items"),
    Some("Example.COM"),
  )
  assert_eq(
    absolute_target_authority("http://example.com?q=1"),
    Some("example.com"),
  )
  assert_eq(
    absolute_target_authority("http://example.com#frag"),
    Some("example.com"),
  )
  assert_eq(absolute_target_authority("http://example.com"), Some("example.com"))
}

///|
test "absolute_target_authority_absent_for_origin_form" {
  assert_eq(absolute_target_authority("/items"), None)
  assert_eq(absolute_target_authority("/items?q=1"), None)
  assert_eq(absolute_target_authority("*"), None)
  assert_eq(absolute_target_authority("example.com:443"), None)
  assert_eq(absolute_target_authority("ftp://example.com/x"), None)
  assert_eq(absolute_target_authority("http://"), None)
  assert_eq(absolute_target_authority("https:///items"), None)
}
