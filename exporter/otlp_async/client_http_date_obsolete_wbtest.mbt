// RFC 9110 requires HTTP-date recipients to accept the obsolete RFC 850 and
// asctime formats in addition to IMF-fixdate. The async OTLP exporter uses the
// parser for `Retry-After` values, where servers occasionally send them.

///|
test "http_date_parser_accepts_rfc850_dates" {
  let cases : Array[(String, Int64)] = [
    ("Sunday, 06-Nov-94 08:49:37 GMT", 784111777L),
    // A three-letter weekday is accepted as well; some intermediaries send it.
    ("Sun, 06-Nov-94 08:49:37 GMT", 784111777L),
    // Two-digit years below 70 are interpreted as 20xx.
    ("Monday, 01-Jan-24 00:00:00 GMT", 1704067200L),
    ("Wednesday, 16-Nov-94 08:49:37 GMT", 784975777L),
  ]
  for entry in cases {
    assert_eq(parse_retry_after_date_seconds(entry.0[:]), Some(entry.1))
  }
}

///|
test "http_date_parser_accepts_asctime_dates" {
  let cases : Array[(String, Int64)] = [
    ("Sun Nov  6 08:49:37 1994", 784111777L),
    ("Wed Nov 16 08:49:37 1994", 784975777L),
    ("Mon Jan  1 00:00:00 2024", 1704067200L),
  ]
  for entry in cases {
    assert_eq(parse_retry_after_date_seconds(entry.0[:]), Some(entry.1))
  }
}

///|
test "http_date_parser_rejects_malformed_obsolete_dates" {
  let cases : Array[String] = [
    // Invalid day in the month.
    "Sunday, 31-Feb-24 00:00:00 GMT",
    "Sun Nov 32 08:49:37 1994",
    "Sun Nov  0 08:49:37 1994",
    // Invalid time of day.
    "Sunday, 06-Nov-94 24:00:00 GMT",
    "Sun Nov  6 00:60:00 1994",
    // Unknown weekday or month.
    "Xxx, 06-Nov-94 08:49:37 GMT",
    "Sunday, 06-Xxx-94 08:49:37 GMT",
    "Xxx Nov  6 08:49:37 1994",
    // Wrong zone or separators.
    "Sunday, 06-Nov-94 08:49:37 UTC",
    "Sunday, 06-Nov-94 08:49:37 GMT ",
    "Sunday 06-Nov-94 08:49:37 GMT",
    "Sun Nov  6 08:49:37 1994 ",
    // Truncated forms must not be accepted.
    "Sunday, 06-Nov-94 08:49:37",
    "Sun Nov 6 08:49:37 1994",
    "Sun Nov  6 08:49:37 194",
  ]
  for value in cases {
    assert_eq(parse_retry_after_date_seconds(value[:]), None)
  }
}

///|
test "retry_after_millis_accepts_obsolete_http_dates" {
  // A date in the past yields no wait.
  assert_eq(retry_after_millis("Sunday, 06-Nov-94 08:49:37 GMT"), Some(0))
  assert_eq(retry_after_millis("Sun Nov  6 08:49:37 1994"), Some(0))
  // A far-future date is capped like an oversized delta-seconds value.
  assert_eq(
    retry_after_millis("Friday, 31-Dec-69 23:59:59 GMT"),
    Some(60000),
  )
  assert_eq(retry_after_millis("Fri Dec 31 23:59:59 9999"), Some(60000))
  assert_eq(retry_after_millis("Sunday, 31-Feb-24 00:00:00 GMT"), None)
}
