// Tests for sanitizing the query component before recording `url.full` or
// `url.query` span attributes.

///|
test "redacts well-known sensitive query parameters" {
  assert_eq(
    @sdk.redact_sensitive_query_string(
      "q=1&X-Amz-Signature=abc&X-Amz-Credential=cred&X-Amz-Security-Token=tok&sig=s&X-Goog-Signature=g",
    ),
    "q=1&X-Amz-Signature=REDACTED&X-Amz-Credential=REDACTED&X-Amz-Security-Token=REDACTED&sig=REDACTED&X-Goog-Signature=REDACTED",
  )
}

///|
test "sensitive query parameter matching is case-insensitive" {
  assert_eq(
    @sdk.redact_sensitive_query_string(
      "x-amz-signature=one&SIG=two&x-goog-signature=three",
    ),
    "x-amz-signature=REDACTED&SIG=REDACTED&x-goog-signature=REDACTED",
  )
}

///|
test "preserves parameter order and separators" {
  assert_eq(
    @sdk.redact_sensitive_query_string("a=1&&sig=two&b=3&"),
    "a=1&&sig=REDACTED&b=3&",
  )
  assert_eq(
    @sdk.redact_sensitive_query_string("sig=a=b&X-Amz-Signature="),
    "sig=REDACTED&X-Amz-Signature=REDACTED",
  )
}

///|
test "leaves unrelated, valueless and encoded parameter names unchanged" {
  assert_eq(
    @sdk.redact_sensitive_query_string(
      "Signature=keep&sig&X%2DAmz%2DSignature=keep",
    ),
    "Signature=keep&sig&X%2DAmz%2DSignature=keep",
  )
  assert_eq(@sdk.redact_sensitive_query_string(""), "")
}
