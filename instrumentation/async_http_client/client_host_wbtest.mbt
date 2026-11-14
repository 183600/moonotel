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
    split_url_host_port("[::ffff:192.168.0.1]", 80),
    Some(("[::ffff:192.168.0.1]", 80)),
  )
  assert_eq(
    split_url_host_port("[fe80::1%25eth0]", 80),
    Some(("[fe80::1%25eth0]", 80)),
  )
  assert_eq(split_url_host_port("[v1.fe80]", 80), Some(("[v1.fe80]", 80)))
  assert_eq(split_url_host_port("example.com", 80), Some(("example.com", 80)))
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
  assert_eq(split_url_host_port("[::1]:not-a-port", 80), Some(("[::1]", -1)))
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
  assert_eq(split_url_host_port("[hello]", 80), None)
  assert_eq(split_url_host_port("[::1::2]", 80), None)
  assert_eq(split_url_host_port("[1:2:3:4:5:6:7]", 80), None)
  assert_eq(split_url_host_port("[1:2:3:4:5:6:7:8:9]", 80), None)
  assert_eq(split_url_host_port("[1:2:3:4:5:6:7:8::]", 80), None)
  assert_eq(split_url_host_port("[::ffff:999.1.1.1]", 80), None)
  assert_eq(split_url_host_port("[::ffff:1.2.3]", 80), None)
  assert_eq(split_url_host_port("[v.fe80]", 80), None)
  assert_eq(split_url_host_port("[v1.]", 80), None)
}

///|
test "split_url_host_port rejects whitespace and control characters" {
  for
    host in [
      "exa mple.com", "example.com:80 80", "example.com\t", "example.com\n", "example.com\r",
      "example.com\u{7F}", "\u{0}example.com",
    ] {
    assert_eq(split_url_host_port(host, 80), None)
  }
}

///|
test "split_url rejects authorities with whitespace or control characters" {
  for
    url in [
      "http://exa mple.com/x", "http://user name@example.com/x", "http://example.com:80 80/x",
      "http://example.com\t/x", "http://example.com\n/x", "http://example.com\r/x",
      "http://example.com\u{7F}/x", "//exa mple.com/x",
    ] {
    assert_eq(split_url(url), ("", -1))
  }
}

///|
test "split_url rejects forbidden URI authority characters" {
  for
    url in [
      "http://exa\"mple.com/x", "http://exa<mple.com/x", "http://exa>mple.com/x",
      "http://exa\\mple.com/x", "http://exa^mple.com/x", "http://exa`mple.com/x",
      "http://exa{mple.com/x", "http://exa|mple.com/x", "http://exa}mple.com/x",
      "http://user\"name@example.com/x", "//exa\\mple.com/x",
    ] {
    assert_eq(split_url(url), ("", -1))
  }
}

///|
test "initial_client_attributes omits server attributes for invalid authorities" {
  for
    url in [
      "http://exa mple.com/x", "http://user name@example.com/x", "http://example.com:80 80/x",
      "http://example.com\t/x", "http://example.com\n/x", "http://example.com\r/x",
      "http://example.com\u{7F}/x", "//exa mple.com/x", "http://exa\"mple.com/x",
      "http://exa<mple.com/x", "http://exa>mple.com/x", "http://exa\\mple.com/x",
      "http://exa^mple.com/x", "http://exa`mple.com/x", "http://exa{mple.com/x",
      "http://exa|mple.com/x", "http://exa}mple.com/x", "http://user\"name@example.com/x",
      "//exa\\mple.com/x",
    ] {
    let attributes = initial_client_attributes(url, @http.RequestMethod::Get, 0)
    assert_eq(attributes.get(@sdk.SERVER_ADDRESS), None)
    assert_eq(attributes.get(@sdk.SERVER_PORT), None)
  }
}

///|
test "initial_client_attributes keeps a valid ipv6 authority" {
  let attributes = initial_client_attributes(
    "http://[::1]:8080/x",
    @http.RequestMethod::Get,
    0,
  )
  assert_eq(attributes.get(@sdk.SERVER_ADDRESS), Some(@sdk.StringValue("::1")))
  assert_eq(attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(8080)))
}

///|
test "initial_client_attributes omits malformed ipv6 authorities" {
  for
    url in [
      "http://[::1/x", "http://[::1]junk/x", "http://::1/x", "http://2001:db8::1/x",
      "http://example.com:8080:90/x", "http://[hello]/x", "http://[::1::2]/x", "http://[1:2:3:4:5:6:7]/x",
      "http://[::ffff:999.1.1.1]/x",
    ] {
    let attributes = initial_client_attributes(url, @http.RequestMethod::Get, 0)
    assert_eq(attributes.get(@sdk.SERVER_ADDRESS), None)
    assert_eq(attributes.get(@sdk.SERVER_PORT), None)
  }
}
