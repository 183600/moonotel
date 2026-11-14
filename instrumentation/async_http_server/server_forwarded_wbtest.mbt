// White-box tests for the `Forwarded` / `X-Forwarded-*` parsing used by
// `server.address`, `server.port` and `url.scheme`.

///|
test "find_delimiter_outside_quotes_ignores_quoted_separators" {
  assert_eq(find_delimiter_outside_quotes("a,b"[:], 0x2C), Some(1))
  assert_eq(find_delimiter_outside_quotes("a\"b,c\",d"[:], 0x2C), Some(6))
  assert_eq(find_delimiter_outside_quotes("a\"b,c\""[:], 0x2C), None)
  assert_eq(find_delimiter_outside_quotes("a;b"[:], 0x3B), Some(1))
  assert_eq(find_delimiter_outside_quotes("a=\"b;c\";d"[:], 0x3B), Some(7))
}

///|
test "unquote_forwarded_value_handles_quoted_and_plain_values" {
  assert_eq(unquote_forwarded_value("example.com"[:]), Some("example.com"))
  assert_eq(unquote_forwarded_value(" \"example.com\" "[:]), Some("example.com"))
  assert_eq(unquote_forwarded_value("\"a\\\"b\""[:]), Some("a\"b"))
  assert_eq(unquote_forwarded_value("\"unterminated"[:]), None)
  assert_eq(unquote_forwarded_value("bad\"quote"[:]), None)
}

///|
test "first_forwarded_parameter_parses_the_first_element" {
  let headers = ows_header_map([
    ("Forwarded", "for=192.0.2.43;host=example.com:8080;proto=https"),
  ])
  assert_eq(first_forwarded_parameter(headers, "for"), Some("192.0.2.43"))
  assert_eq(
    first_forwarded_parameter(headers, "host"),
    Some("example.com:8080"),
  )
  assert_eq(first_forwarded_parameter(headers, "proto"), Some("https"))
  assert_eq(first_forwarded_parameter(headers, "missing"), None)
  assert_eq(first_forwarded_parameter(ows_header_map([]), "host"), None)
}

///|
test "first_forwarded_parameter_is_case_insensitive_and_trims_ows" {
  let headers = ows_header_map([
    ("Forwarded", " for=1.2.3.4 ; Host = \"example.com\" ; proto=HTTPS "),
  ])
  assert_eq(first_forwarded_parameter(headers, "host"), Some("example.com"))
  assert_eq(first_forwarded_parameter(headers, "proto"), Some("HTTPS"))
}

///|
test "first_forwarded_parameter_ignores_later_elements" {
  let headers = ows_header_map([
    ("Forwarded", "for=1.2.3.4, for=5.6.7.8;host=later.example.com"),
  ])
  assert_eq(first_forwarded_parameter(headers, "host"), None)
}

///|
test "first_forwarded_parameter_ignores_commas_inside_quotes" {
  let headers = ows_header_map([
    ("Forwarded", "for=\"a,b\";host=example.com, for=1.2.3.4"),
  ])
  assert_eq(first_forwarded_parameter(headers, "host"), Some("example.com"))
}

///|
test "first_header_token_takes_the_original_value" {
  let headers = ows_header_map([
    ("X-Forwarded-Host", " public.example.com:8443 , proxy.internal "),
  ])
  assert_eq(
    first_header_token(headers, "x-forwarded-host"),
    Some("public.example.com:8443"),
  )
  assert_eq(first_header_token(headers, "missing"), None)
  assert_eq(
    first_header_token(ows_header_map([("X-Forwarded-Host", "  ")]), "x-forwarded-host"),
    None,
  )
}

///|
test "effective_request_scheme_prefers_forwarded_proto" {
  assert_eq(effective_request_scheme(ows_header_map([]), "/items"), "http")
  assert_eq(
    effective_request_scheme(
      ows_header_map([("X-Forwarded-Proto", "https")]),
      "/items",
    ),
    "https",
  )
  assert_eq(
    effective_request_scheme(
      ows_header_map([
        ("Forwarded", "proto=HTTPS"),
        ("X-Forwarded-Proto", "http"),
      ]),
      "/items",
    ),
    "https",
  )
  assert_eq(
    effective_request_scheme(
      ows_header_map([
        ("Forwarded", "proto=ftp"),
        ("X-Forwarded-Proto", "https"),
      ]),
      "/items",
    ),
    "https",
  )
  assert_eq(
    effective_request_scheme(
      ows_header_map([("Forwarded", "proto=ftp")]),
      "https://backend.internal/items",
    ),
    "https",
  )
}

///|
test "effective_forwarded_host_prefers_forwarded_and_skips_invalid_values" {
  assert_eq(
    effective_forwarded_host(
      ows_header_map([("X-Forwarded-Host", "x.example.com")]),
    ),
    Some("x.example.com"),
  )
  assert_eq(
    effective_forwarded_host(
      ows_header_map([
        ("Forwarded", "host=f.example.com"),
        ("X-Forwarded-Host", "x.example.com"),
      ]),
    ),
    Some("f.example.com"),
  )
  assert_eq(
    effective_forwarded_host(
      ows_header_map([
        ("Forwarded", "host=\"bad host\""),
        ("X-Forwarded-Host", "x.example.com"),
      ]),
    ),
    Some("x.example.com"),
  )
}

///|
test "parse_forwarded_node_accepts_ip_literals_and_ports" {
  assert_eq(
    parse_forwarded_node("192.0.2.43"),
    Some(("192.0.2.43", None)),
  )
  assert_eq(
    parse_forwarded_node("192.0.2.43:1234"),
    Some(("192.0.2.43", Some(1234))),
  )
  assert_eq(
    parse_forwarded_node("0.0.0.0:0"),
    Some(("0.0.0.0", Some(0))),
  )
  assert_eq(
    parse_forwarded_node("[2001:db8::1]"),
    Some(("2001:db8::1", None)),
  )
  assert_eq(
    parse_forwarded_node("[2001:db8::1]:4711"),
    Some(("2001:db8::1", Some(4711))),
  )
  assert_eq(
    parse_forwarded_node("2001:db8::1"),
    Some(("2001:db8::1", None)),
  )
  assert_eq(
    parse_forwarded_node("[2001:db8::1%25eth0]:4711"),
    Some(("2001:db8::1%25eth0", Some(4711))),
  )
  assert_eq(
    parse_forwarded_node("[::ffff:192.0.2.1]"),
    Some(("::ffff:192.0.2.1", None)),
  )
}

///|
test "parse_forwarded_node_rejects_unknown_and_malformed_values" {
  for value in [
    "", "unknown", "_gazonk", "192.0.2.43:", "192.0.2.43:not-a-port",
    "[2001:db8::1", "[2001:db8::1]junk", "[2001:db8::1]:",
    "192.0.2.43:80:90", "01.2.3.4", "192.168.001.1:80", "0x7f.0.0.1",
    "1.2.3.4:+80", "1.2.3", "[::1%]", "[1:2:3:4:5:6:7:8:9]",
  ] {
    assert_eq(parse_forwarded_node(value), None)
  }
}

///|
test "effective_forwarded_client_prefers_forwarded_for" {
  assert_eq(
    effective_forwarded_client(
      ows_header_map([("Forwarded", "for=192.0.2.1;host=x")]),
    ),
    Some(("192.0.2.1", None)),
  )
  assert_eq(
    effective_forwarded_client(
      ows_header_map([("X-Forwarded-For", "192.0.2.2, 10.0.0.1")]),
    ),
    Some(("192.0.2.2", None)),
  )
  assert_eq(
    effective_forwarded_client(
      ows_header_map([
        ("Forwarded", "for=\"[2001:db8::1]:4711\""),
        ("X-Forwarded-For", "10.0.0.1"),
      ]),
    ),
    Some(("2001:db8::1", Some(4711))),
  )
}

///|
test "effective_forwarded_client_does_not_fall_back_from_an_unusable_forwarded_for" {
  assert_eq(
    effective_forwarded_client(
      ows_header_map([
        ("Forwarded", "for=unknown"),
        ("X-Forwarded-For", "10.0.0.1"),
      ]),
    ),
    None,
  )
}

///|
test "effective_forwarded_client_falls_back_to_x_forwarded_for" {
  assert_eq(
    effective_forwarded_client(
      ows_header_map([
        ("Forwarded", "host=example.com"),
        ("X-Forwarded-For", "10.0.0.1"),
      ]),
    ),
    Some(("10.0.0.1", None)),
  )
}

///|
test "record_host_attributes_uses_forwarded_host_and_proto" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(
    span,
    ows_header_map([
      ("Host", "backend.internal"),
      ("X-Forwarded-Host", "public.example.com"),
      ("X-Forwarded-Proto", "https"),
    ]),
    "/items",
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(
    data.attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("public.example.com")),
  )
  assert_eq(data.attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(443)))
}

///|
test "record_host_attributes_prefers_forwarded_over_an_absolute_target" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(
    span,
    ows_header_map([
      ("Forwarded", "host=public.example.com:9443;proto=https"),
      ("Host", "backend.internal"),
    ]),
    "http://backend.internal:8080/items",
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(
    data.attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("public.example.com")),
  )
  assert_eq(data.attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(9443)))
}

///|
test "record_host_attributes_falls_back_from_an_invalid_forwarded_host" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(
    span,
    ows_header_map([
      ("Host", "example.com:9090"),
      ("Forwarded", "host=\"bad host\""),
    ]),
    "/items",
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(
    data.attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("example.com")),
  )
  assert_eq(data.attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(9090)))
}
