// Tests for sanitizing the query component before recording `url.full` or
// `url.query` span attributes.

///|
test "redacts well-known sensitive query parameters" {
  assert_eq(
    @sdk.redact_sensitive_query_string(
      "q=1&X-Amz-Signature=abc&X-Amz-Credential=cred&X-Amz-Security-Token=tok&AWSAccessKeyId=key&Signature=cloud&sig=s&X-Goog-Signature=g",
    ),
    "q=1&X-Amz-Signature=REDACTED&X-Amz-Credential=REDACTED&X-Amz-Security-Token=REDACTED&AWSAccessKeyId=REDACTED&Signature=REDACTED&sig=REDACTED&X-Goog-Signature=REDACTED",
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
test "leaves unrelated and valueless parameter names unchanged" {
  assert_eq(
    @sdk.redact_sensitive_query_string(
      "SignatureValue=keep&sig&X-Amz-SignatureValue=keep",
    ),
    "SignatureValue=keep&sig&X-Amz-SignatureValue=keep",
  )
  assert_eq(@sdk.redact_sensitive_query_string(""), "")
}

///|
test "redacts percent-encoded sensitive parameter names" {
  assert_eq(
    @sdk.redact_sensitive_query_string(
      "X%2DAmz%2DSignature=secret&%58-Amz-Credential=cred&x%2damz%2dsecurity%2dtoken=tok",
    ),
    "X%2DAmz%2DSignature=REDACTED&%58-Amz-Credential=REDACTED&x%2damz%2dsecurity%2dtoken=REDACTED",
  )
  // A malformed escape cannot name a sensitive parameter and stays as-is.
  assert_eq(
    @sdk.redact_sensitive_query_string(
      "X%2DAmz%2DSignature=secret&X%ZZ-Amz-Signature=keep&sig%2",
    ),
    "X%2DAmz%2DSignature=REDACTED&X%ZZ-Amz-Signature=keep&sig%2",
  )
}

///|
test "redacts AWS access key id and CloudFront signature parameters" {
  assert_eq(
    @sdk.redact_sensitive_query_string(
      "AWSAccessKeyId=key&Signature=cloud&awsaccesskeyid=lower&signature=lower",
    ),
    "AWSAccessKeyId=REDACTED&Signature=REDACTED&awsaccesskeyid=REDACTED&signature=REDACTED",
  )
}
