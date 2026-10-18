// White-box tests for the `Retry-After` parsing helpers of the async
// OTLP/HTTP exporter.

///|
test "parse_http_date_seconds parses IMF-fixdate values" {
  assert_eq(
    parse_http_date_seconds("Thu, 01 Jan 1970 00:00:00 GMT"[:]),
    Some(0L),
  )
  assert_eq(
    parse_http_date_seconds("Sun, 06 Nov 1994 08:49:37 GMT"[:]),
    Some(784111777L),
  )
  assert_eq(
    parse_http_date_seconds("Sat, 01 Jan 2000 00:00:00 GMT"[:]),
    Some(946684800L),
  )
  assert_eq(
    parse_http_date_seconds("Mon, 01 Jan 2024 00:00:00 GMT"[:]),
    Some(1704067200L),
  )
  // A leap day in a leap year.
  assert_eq(
    parse_http_date_seconds("Thu, 29 Feb 2024 12:00:00 GMT"[:]),
    Some(1709208000L),
  )
}

///|
test "parse_http_date_seconds rejects non-IMF-fixdate values" {
  let invalid : Array[String] = [
    "", "Sun, 06 Nov 1994 08:49:37", "Sun, 06 Nov 1994 08:49:37 GMT extra", "Sunday, 06-Nov-94 08:49:37 GMT",
    "Sun Nov  6 08:49:37 1994", "Sun, 06 Nov 1994 08:49:37 UTC", "Xyz, 06 Nov 1994 08:49:37 GMT",
    "Sun, 06 Xxx 1994 08:49:37 GMT", "Sun, 06 Nov 19x4 08:49:37 GMT", "Sun, 00 Nov 1994 08:49:37 GMT",
    "Sun, 32 Nov 1994 08:49:37 GMT", "Sun, 06 Nov 1994 24:49:37 GMT", "Sun, 06 Nov 1994 08:60:37 GMT",
    "Sun, 06 Nov 1994 08:49:3a GMT",
  ]
  for value in invalid {
    assert_eq(parse_http_date_seconds(value[:]), None)
  }
}

///|
test "retry_after_millis handles seconds and dates" {
  assert_eq(retry_after_millis("0"), Some(0))
  assert_eq(retry_after_millis(" 5 "), Some(5000))
  assert_eq(retry_after_millis("60"), Some(60000))
  // Larger values are capped so a server cannot stall the exporter.
  assert_eq(retry_after_millis("120"), Some(60000))
  assert_eq(retry_after_millis("-1"), None)
  assert_eq(retry_after_millis(""), None)
  assert_eq(retry_after_millis("not-a-delay"), None)
  // Dates in the past mean "retry immediately".
  assert_eq(retry_after_millis("Sun, 06 Nov 1994 08:49:37 GMT"), Some(0))
  assert_eq(retry_after_millis("Thu, 01 Jan 1970 00:00:00 GMT"), Some(0))
  // A date far in the future is capped like an oversized delay.
  assert_eq(retry_after_millis("Mon, 01 Jan 2999 00:00:00 GMT"), Some(60000))
}
