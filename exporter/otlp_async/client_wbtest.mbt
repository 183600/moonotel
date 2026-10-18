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
test "parse_http_date_seconds rejects impossible calendar days" {
  let invalid : Array[String] = [
    "Sun, 31 Feb 2024 00:00:00 GMT", "Sun, 30 Feb 2024 00:00:00 GMT", "Tue, 31 Apr 2024 00:00:00 GMT",
    "Fri, 31 Jun 1994 08:49:37 GMT", "Sat, 31 Sep 1994 08:49:37 GMT", "Mon, 31 Nov 1994 08:49:37 GMT",
  ]
  for value in invalid {
    assert_eq(parse_http_date_seconds(value[:]), None)
  }
}

///|
test "parse_http_date_seconds honors month lengths and leap years" {
  // February ends on the 29th in a leap year and on the 28th otherwise.
  assert_eq(
    parse_http_date_seconds("Thu, 29 Feb 2024 00:00:00 GMT"[:]),
    Some(1709164800L),
  )
  assert_eq(
    parse_http_date_seconds("Tue, 28 Feb 2023 00:00:00 GMT"[:]),
    Some(1677542400L),
  )
  // The 29th of February exists in 2024 but not in 2023 or 2100 (century
  // years are leap years only when divisible by 400).
  assert_eq(parse_http_date_seconds("Wed, 29 Feb 2023 00:00:00 GMT"[:]), None)
  assert_eq(parse_http_date_seconds("Mon, 29 Feb 2100 00:00:00 GMT"[:]), None)
  // 30-day months end on the 30th; 31-day months on the 31st.
  assert_eq(
    parse_http_date_seconds("Tue, 30 Apr 2024 00:00:00 GMT"[:]),
    Some(1714435200L),
  )
  assert_eq(
    parse_http_date_seconds("Sun, 31 Dec 2023 00:00:00 GMT"[:]),
    Some(1703980800L),
  )
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
