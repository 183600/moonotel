// Whitebox tests for the HTTP-date and Retry-After parsing helpers used by the
// async OTLP exporter.

///|
test "http_date_parser_handles_every_month_and_leap_years" {
  // Expected values are Unix seconds for the corresponding UTC dates.
  let cases : Array[(String, Int64)] = [
    ("Mon, 01 Jan 2024 00:00:00 GMT", 1704067200L),
    ("Thu, 29 Feb 2024 12:34:56 GMT", 1709210096L),
    ("Mon, 01 Mar 2021 00:00:00 GMT", 1614556800L),
    ("Thu, 01 Apr 2021 00:00:00 GMT", 1617235200L),
    ("Sat, 01 May 2021 00:00:00 GMT", 1619827200L),
    ("Tue, 01 Jun 2021 00:00:00 GMT", 1622505600L),
    ("Thu, 01 Jul 2021 00:00:00 GMT", 1625097600L),
    ("Sun, 01 Aug 2021 00:00:00 GMT", 1627776000L),
    ("Wed, 01 Sep 2021 00:00:00 GMT", 1630454400L),
    ("Fri, 01 Oct 2021 00:00:00 GMT", 1633046400L),
    ("Mon, 01 Nov 2021 00:00:00 GMT", 1635724800L),
    ("Wed, 01 Dec 2021 00:00:00 GMT", 1638316800L),
    ("Tue, 29 Feb 2000 00:00:00 GMT", 951782400L),
  ]
  for entry in cases {
    assert_eq(parse_http_date_seconds(entry.0[:]), Some(entry.1))
  }
}

///|
test "http_date_parser_rejects_invalid_dates_and_times" {
  let cases : Array[String] = [
    // Day outside the month (2024 is a leap year, 1900 is not).
    "Mon, 31 Feb 2024 00:00:00 GMT",
    "Mon, 29 Feb 1900 00:00:00 GMT",
    "Mon, 01 Jan 2024 24:00:00 GMT",
    "Mon, 01 Jan 2024 00:60:00 GMT",
    "Mon, 01 Jan 2024 00:00:61 GMT",
    // Unknown weekday, wrong length and wrong timezone suffix.
    "Xxx, 01 Jan 2024 00:00:00 GMT",
    "Mon 01 Jan 2024 00:00:00 GMT",
    "Mon, 01 Jan 2024 00:00:00 UTC",
    "Mon, 01 Jan 2024 00:00:00 GMT ",
    // Non-digit components.
    "Mon, 0x Jan 2024 00:00:00 GMT",
    "Mon, 01 Xxx 2024 00:00:00 GMT",
    "Mon, 01 Jan 20x4 00:00:00 GMT",
    "Mon, 01 Jan 2024 0x:00:00 GMT",
  ]
  for value in cases {
    assert_eq(parse_http_date_seconds(value[:]), None)
  }
}

///|
test "retry_after_seconds_accepts_digits_and_caps_at_one_minute" {
  assert_eq(parse_retry_after_seconds("0"[:]), Some(0))
  assert_eq(parse_retry_after_seconds("5"[:]), Some(5))
  assert_eq(parse_retry_after_seconds("60"[:]), Some(60))
  assert_eq(parse_retry_after_seconds("61"[:]), Some(60))
  assert_eq(parse_retry_after_seconds("999999999999999999999"[:]), Some(60))
  assert_eq(parse_retry_after_seconds(""[:]), None)
  assert_eq(parse_retry_after_seconds("-1"[:]), None)
  assert_eq(parse_retry_after_seconds("1.5"[:]), None)
}

///|
test "retry_after_millis_combines_seconds_and_dates" {
  assert_eq(retry_after_millis("0"), Some(0))
  assert_eq(retry_after_millis(" 5 "), Some(5000))
  assert_eq(retry_after_millis("61"), Some(60000))
  assert_eq(retry_after_millis("Sun, 06 Nov 1994 08:49:37 GMT"), Some(0))
  assert_eq(retry_after_millis("Fri, 31 Dec 9999 23:59:59 GMT"), Some(60000))
  assert_eq(retry_after_millis("not-a-delay"), None)
  assert_eq(retry_after_millis(""), None)
  assert_eq(retry_after_millis("Mon, 31 Feb 2024 00:00:00 GMT"), None)
}
