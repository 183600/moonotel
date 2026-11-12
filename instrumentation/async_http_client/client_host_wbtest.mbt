// White-box tests for the IPv6 bracket stripping used by `server.address`.

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
test "split_url_host_port parses valid hosts" {
  assert_eq(split_url_host_port("[::1]", 80), Some(("[::1]", 80)))
  assert_eq(split_url_host_port("[::1]:8080", 80), Some(("[::1]", 8080)))
  assert_eq(split_url_host_port("[::1]:", 443), Some(("[::1]", 443)))
  assert_eq(
    split_url_host_port("[2001:db8::1]:4318", 80),
    Some(("[2001:db8::1]", 4318)),
  )
  assert_eq(
    split_url_host_port("example.com", 80),
    Some(("example.com", 80)),
  )
  assert_eq(
    split_url_host_port("example.com:", 443),
    Some(("example.com", 443)),
  )
  assert_eq(
    split_url_host_port("example.com:8080", 80),
    Some(("example.com", 8080)),
  )
  assert_eq(
    split_url_host_port("example.com:not-a-port", 80),
    Some(("example.com", -1)),
  )
  assert_eq(
    split_url_host_port("[::1]:not-a-port", 80),
    Some(("[::1]", -1)),
  )
}

///|
test "split_url_host_port rejects malformed ipv6 literals" {
  assert_eq(split_url_host_port("[::1", 80), None)
  assert_eq(split_url_host_port("[::1]junk", 80), None)
  assert_eq(split_url_host_port("[::1]junk:8080", 80), None)
  assert_eq(split_url_host_port("[[::1]]", 80), None)
  assert_eq(split_url_host_port("::1", 80), None)
  assert_eq(split_url_host_port("2001:db8::1", 80), None)
  assert_eq(split_url_host_port("example.com:8080:90", 80), None)
  assert_eq(split_url_host_port("foo]", 80), None)
}

///|
test "initial_client_attributes keeps a valid ipv6 authority" {
  let attributes = initial_client_attributes(
    "http://[::1]:8080/x",
    @http.RequestMethod::Get,
    0,
  )
  assert_eq(
    attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("::1")),
  )
  assert_eq(attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(8080)))
}

///|
test "initial_client_attributes omits malformed ipv6 authorities" {
  for url in [
    "http://[::1/x", "http://[::1]junk/x", "http://::1/x",
    "http://2001:db8::1/x", "http://example.com:8080:90/x",
  ] {
    let attributes = initial_client_attributes(
      url,
      @http.RequestMethod::Get,
      0,
    )
    assert_eq(attributes.get(@sdk.SERVER_ADDRESS), None)
    assert_eq(attributes.get(@sdk.SERVER_PORT), None)
  }
}
