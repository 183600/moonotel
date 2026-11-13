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

///|
test "split_host_authority parses valid hosts" {
  assert_eq(split_host_authority("[::1]", 80), Some(("::1", 80)))
  assert_eq(split_host_authority("[::1]:8080", 80), Some(("::1", 8080)))
  assert_eq(split_host_authority("[::1]:", 443), Some(("::1", 443)))
  assert_eq(
    split_host_authority("[2001:db8::1]:4318", 80),
    Some(("2001:db8::1", 4318)),
  )
  assert_eq(split_host_authority("example.com", 80), Some(("example.com", 80)))
  assert_eq(
    split_host_authority("example.com:", 443),
    Some(("example.com", 443)),
  )
  assert_eq(
    split_host_authority("example.com:8080", 80),
    Some(("example.com", 8080)),
  )
  assert_eq(
    split_host_authority("example.com:not-a-port", 80),
    Some(("example.com", -1)),
  )
  assert_eq(
    split_host_authority("[::1]:not-a-port", 80),
    Some(("::1", -1)),
  )
}

///|
test "split_host_authority rejects malformed ipv6 literals" {
  assert_eq(split_host_authority("[::1", 80), None)
  assert_eq(split_host_authority("[::1]junk", 80), None)
  assert_eq(split_host_authority("[::1]junk:8080", 80), None)
  assert_eq(split_host_authority("[[::1]]", 80), None)
  assert_eq(split_host_authority("::1", 80), None)
  assert_eq(split_host_authority("2001:db8::1", 80), None)
  assert_eq(split_host_authority("example.com:8080:90", 80), None)
  assert_eq(split_host_authority("foo]", 80), None)
}

///|
test "split_host_authority rejects whitespace and control characters" {
  for authority in [
    "exa mple.com", "exa\tmple.com", "exa\nmple.com", "exa\rmple.com",
    "example.com :8080", "[::1] ", "[:: 1]", "example.com:\u{0001}",
    "\u{007f}example.com",
  ] {
    assert_eq(split_host_authority(authority, 80), None)
  }
}

///|
test "split_host_authority rejects forbidden URI authority characters" {
  for authority in [
    "exa\"mple.com", "exa<mple.com", "exa>mple.com", "exa@mple.com",
    "exa\\mple.com", "exa^mple.com", "exa`mple.com", "exa{mple.com",
    "exa|mple.com", "exa}mple.com", "example.com\\path",
    "example.com:80\"x\"", "user@example.com", "example.com:80@evil",
  ] {
    assert_eq(split_host_authority(authority, 80), None)
  }
}

///|
test "split_host_authority rejects URI delimiters" {
  assert_eq(split_host_authority("example.com/path", 80), None)
  assert_eq(split_host_authority("example.com?q=1", 80), None)
  assert_eq(split_host_authority("example.com#frag", 80), None)
  assert_eq(split_host_authority("/path", 80), None)
  assert_eq(split_host_authority("example.com:8080/path", 80), None)
}

///|
test "record_host_attributes ignores malformed host authorities" {
  for host in [
    "[::1", "[::1]junk", "[::1]junk:8080", "[[::1]]", "::1", "2001:db8::1",
    "example.com:8080:90", "foo]", "example.com/path", "example.com?q=1",
    "example.com#frag", "exa\"mple.com", "exa<mple.com", "exa\\mple.com",
    "exa|mple.com",
  ] {
    let (span, exporter) = host_attribute_span()
    record_host_attributes(span, ows_header_map([("Host", host)]), "/")
    span.end()
    let data = exporter.exported_spans()[0]
    assert_eq(data.attributes.get(@sdk.SERVER_ADDRESS), None)
    assert_eq(data.attributes.get(@sdk.SERVER_PORT), None)
  }
}

///|
test "record_host_attributes ignores a malformed absolute authority" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(
    span,
    ows_header_map([("Host", "fallback.example.com")]),
    "http://[::1/path",
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(data.attributes.get(@sdk.SERVER_ADDRESS), None)
  assert_eq(data.attributes.get(@sdk.SERVER_PORT), None)
}

///|
test "record_host_attributes keeps a valid ipv6 host with an invalid port" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(
    span,
    ows_header_map([("Host", "[::1]:not-a-port")]),
    "/",
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(
    data.attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("::1")),
  )
  assert_eq(data.attributes.get(@sdk.SERVER_PORT), None)
}
