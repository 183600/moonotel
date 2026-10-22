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
