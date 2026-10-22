// `server.port` is required whenever `server.address` is recorded. When the
// authority omits the port (or has an empty one), the scheme default applies.

///|
test "record_host_attributes_uses_the_http_default_port" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(span, ows_header_map([("Host", "example.com")]), "/")
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(
    data.attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("example.com")),
  )
  assert_eq(
    data.attributes.get(@sdk.SERVER_PORT),
    Some(@sdk.IntValue(80)),
  )
}

///|
test "record_host_attributes_uses_the_https_default_port" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(
    span,
    ows_header_map([("Host", "ignored.example.com")]),
    "https://example.com/items",
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(
    data.attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("example.com")),
  )
  assert_eq(
    data.attributes.get(@sdk.SERVER_PORT),
    Some(@sdk.IntValue(443)),
  )
}

///|
test "record_host_attributes_uses_the_default_for_an_empty_port" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(span, ows_header_map([("Host", "example.com:")]), "/")
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(
    data.attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("example.com")),
  )
  assert_eq(
    data.attributes.get(@sdk.SERVER_PORT),
    Some(@sdk.IntValue(80)),
  )
}

///|
test "record_host_attributes_defaults_a_bracketed_ipv6_port" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(span, ows_header_map([("Host", "[::1]")]), "/")
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(
    data.attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("::1")),
  )
  assert_eq(
    data.attributes.get(@sdk.SERVER_PORT),
    Some(@sdk.IntValue(80)),
  )
}

///|
test "record_host_attributes_still_omits_an_invalid_explicit_port" {
  let (span, exporter) = host_attribute_span()
  record_host_attributes(
    span,
    ows_header_map([("Host", "example.com:not-a-port")]),
    "/",
  )
  span.end()
  let data = exporter.exported_spans()[0]
  assert_eq(
    data.attributes.get(@sdk.SERVER_ADDRESS),
    Some(@sdk.StringValue("example.com")),
  )
  assert_eq(data.attributes.get(@sdk.SERVER_PORT), None)
}
