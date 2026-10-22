// Regression tests for the stable helpers re-exported by the facade package.

///|
test "facade_reexports_resource_attributes" {
  let attributes : Map[String, @moonotel.AttributeValue] = Map([
    ("service.version", @moonotel.AttributeValue::StringValue("1.2.3")),
  ])
  let resource : @moonotel.ResourceAttributes = @moonotel.ResourceAttributes::new(
    attributes,
  )
  assert_eq(
    resource.get("service.version"),
    Some(@moonotel.AttributeValue::StringValue("1.2.3")),
  )
  assert_eq(resource.length(), 1)
}

///|
test "facade_reexports_query_redaction" {
  assert_eq(
    @moonotel.redact_sensitive_query_string(
      "a=1&X-Amz-Signature=secret&b=2",
    ),
    "a=1&X-Amz-Signature=REDACTED&b=2",
  )
}

///|
test "facade_reexports_baggage_percent_helpers" {
  let encoded = @moonotel.percent_encode("a b,c")
  assert_eq(encoded, "a%20b%2Cc")
  assert_eq(@moonotel.percent_encoded_length("a b,c"), encoded.length())
  assert_eq(@moonotel.percent_decode(encoded), Some("a b,c"))
}

///|
test "facade_reexports_retry_wait" {
  let wait : @moonotel.RetryWait = fn(_attempt) { () }
  wait(1)
}

///|
test "facade_reexports_api_hex_helpers" {
  assert_eq(@moonotel.byte_to_hex_char(10), "a")
  assert_true(@moonotel.is_zero(Array::make(16, 0)))
  assert_false(@moonotel.is_zero([1]))
}

///|
test "facade_reexports_context_baggage_entries" {
  let entry : @moonotel.ContextBaggageEntry = @moonotel.ContextBaggageEntry::new(
    "user.id",
    "42",
    properties=[("ttl", "1")],
  )
  let context = @moonotel.Context::root().with_baggage_entries([entry])
  assert_eq(context.value("user.id"), Some("42"))
  match context.baggage_entry("user.id") {
    Some(stored) => assert_eq(stored.properties, [("ttl", "1")])
    None => fail("expected the context baggage entry to be stored")
  }
}

///|
test "facade_reexports_http_header_validation" {
  assert_true(@moonotel.is_valid_http_header_name("x-token"))
  assert_false(@moonotel.is_valid_http_header_name("bad name"))
  assert_true(@moonotel.is_valid_http_header_value("café"))
  assert_false(@moonotel.is_valid_http_header_value("a\r\nb"))
}
