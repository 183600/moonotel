// Whole-number JSON exponent/decimal forms for `rejectedSpans` are normalized
// before the int64 range check. Leading zeroes in the fraction and trailing
// zeroes cancelled by a negative exponent must not be mistaken for malformed
// or out-of-range input.

///|
fn decode_normalized_number_body(text : String) -> @sdk.ExportResult {
  @otlp.decode_export_response_json(@utf8.encode(text))
}

///|
fn normalized_number_failure_message(result : @sdk.ExportResult) -> String {
  match result {
    @sdk.ExportFailure(message) => message
    @sdk.ExportSuccess => abort("expected an export failure")
  }
}

///|
test "json_decode_accepts_normalized_whole_number_forms" {
  let cases = [
    ("0.0000000000000000000001e22", "1"),
    ("12300e-2", "123"),
    ("1e0000002", "100"),
    ("9223372036854775807.0", "9223372036854775807"),
  ]
  for pair in cases {
    let (number, expected) = pair
    let message = normalized_number_failure_message(
      decode_normalized_number_body(
        "{\"partialSuccess\":{\"rejectedSpans\":" + number + "}}",
      ),
    )
    assert_true(message.contains("rejected " + expected + " span(s)"))
  }
}

///|
test "json_decode_accepts_zero_with_any_exponent_or_sign" {
  assert_eq(
    decode_normalized_number_body(
      "{\"partialSuccess\":{\"rejectedSpans\":0e5}}",
    ),
    @sdk.ExportSuccess,
  )
  assert_eq(
    decode_normalized_number_body(
      "{\"partialSuccess\":{\"rejectedSpans\":-0.0e1000000}}",
    ),
    @sdk.ExportSuccess,
  )
}

///|
test "json_decode_rejects_fractional_or_overflowing_normalized_forms" {
  for number in ["1e-2", "9223372036854775808.0", "1e999999999"] {
    assert_false(
      decode_normalized_number_body(
        "{\"partialSuccess\":{\"rejectedSpans\":" + number + "}}",
      ).is_success(),
    )
  }
}
