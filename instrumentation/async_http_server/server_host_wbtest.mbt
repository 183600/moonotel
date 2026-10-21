// White-box tests for the IPv6 bracket stripping used by `server.address`.

///|
test "parse_port_rejects_values_that_would_overflow" {
  assert_eq(parse_port("8080"[:]), 8080)
  assert_eq(parse_port("65535"[:]), 65535)
  assert_eq(parse_port("65536"[:]), -1)
  assert_eq(parse_port("4294967296"[:]), -1)
  assert_eq(parse_port("999999999999999999999"[:]), -1)
}

///|
test "strip_ipv6_brackets_removes_uri_delimiters" {
  assert_eq(strip_ipv6_brackets("[::1]"), "::1")
  assert_eq(strip_ipv6_brackets("[2001:db8::1]"), "2001:db8::1")
  assert_eq(strip_ipv6_brackets("[fe80::1%25eth0]"), "fe80::1%25eth0")
  assert_eq(strip_ipv6_brackets("::1"), "::1")
  assert_eq(strip_ipv6_brackets("example.com"), "example.com")
  assert_eq(strip_ipv6_brackets("127.0.0.1"), "127.0.0.1")
  assert_eq(strip_ipv6_brackets("["), "[")
  assert_eq(strip_ipv6_brackets("]"), "]")
}
