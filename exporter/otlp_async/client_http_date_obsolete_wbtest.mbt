// RFC 9110 requires HTTP-date recipients to accept the obsolete RFC 850 and
// asctime formats in addition to IMF-fixdate. The async OTLP exporter uses the
// parser for `Retry-After` values, where servers occasionally send them.

///|
test "http_date_parser_accepts_rfc850_dates" {
  let cases : Array[(String, Int64)] = [
    ("Sunday, 06-Nov-94 08:49:37 GMT", 784111777L),
    // A three-letter weekday is accepted as well; some intermediaries send it.
    ("Sun, 06-Nov-94 08:49:37 GMT", 784111777L),
    // A recent two-digit year resolves to the current century.
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
    "Sunday, 31-Feb-24 00:00:00 GMT", "Sun Nov 32 08:49:37 1994", "Sun Nov  0 08:49:37 1994",
    // Invalid time of day.
     "Sunday, 06-Nov-94 24:00:00 GMT", "Sun Nov  6 00:60:00 1994",
    // Unknown weekday or month.
     "Xxx, 06-Nov-94 08:49:37 GMT", "Sunday, 06-Xxx-94 08:49:37 GMT", "Xxx Nov  6 08:49:37 1994",
    // Wrong zone or separators.
     "Sunday, 06-Nov-94 08:49:37 UTC", "Sunday, 06-Nov-94 08:49:37 GMT ", "Sunday 06-Nov-94 08:49:37 GMT",
    // RFC 850 requires a space after the comma, not any other character.
     "Sunday,X06-Nov-94 08:49:37 GMT", "Sunday,\t06-Nov-94 08:49:37 GMT", "Sun Nov  6 08:49:37 1994 ",
    // Truncated forms must not be accepted.
     "Sunday, 06-Nov-94 08:49:37", "Sun Nov 6 08:49:37 1994", "Sun Nov  6 08:49:37 194",
    // Non-digit components in RFC 850 dates.
     "Sunday, x6-Nov-24 00:00:00 GMT", "Sunday, 06-Nov-x4 00:00:00 GMT", "Sunday, 06-Nov-24 x0:00:00 GMT",
    "Sunday, 06-Nov-24 00:x0:00 GMT", "Sunday, 06-Nov-24 00:00:x0 GMT",
    // Non-digit components in asctime dates.
     "Sun Xxx  6 08:49:37 1994", "Sun Nov  x 08:49:37 1994", "Sun Nov x6 08:49:37 1994",
    "Sun Nov  6 x8:49:37 1994", "Sun Nov  6 08:x9:37 1994", "Sun Nov  6 08:49:x7 1994",
    "Sun Nov  6 08:49:37 x994", "Sun Nov  6 08:49:37 19x4",
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
  assert_eq(retry_after_millis("Friday, 31-Dec-69 23:59:59 GMT"), Some(60000))
  assert_eq(retry_after_millis("Fri Dec 31 23:59:59 9999"), Some(60000))
  assert_eq(retry_after_millis("Sunday, 31-Feb-24 00:00:00 GMT"), None)
  // A malformed RFC 850 separator must fall back to the retry backoff.
  assert_eq(retry_after_millis("Sunday,X06-Nov-94 08:49:37 GMT"), None)
}

///|
test "rfc850_two_digit_year_uses_the_current_year_window" {
  // RFC 9110: a timestamp more than 50 years in the future denotes the most
  // recent past year with the same last two digits. Years exactly 50 years
  // ahead are still future.
  assert_eq(expand_two_digit_year(0, 2026), 2000)
  assert_eq(expand_two_digit_year(24, 2026), 2024)
  assert_eq(expand_two_digit_year(26, 2026), 2026)
  assert_eq(expand_two_digit_year(76, 2026), 2076)
  assert_eq(expand_two_digit_year(77, 2026), 1977)
  assert_eq(expand_two_digit_year(99, 2026), 1999)
  // The window moves with the current year instead of using a fixed cutoff.
  assert_eq(expand_two_digit_year(20, 2050), 2020)
  assert_eq(expand_two_digit_year(20, 2150), 2120)
  assert_eq(expand_two_digit_year(20, 2201), 2220)
  assert_eq(expand_two_digit_year(80, 2201), 2180)
}

///|
fn two_digit_year(year : Int32) -> String {
  let remainder = year % 100
  if remainder < 10 {
    "0" + remainder.to_string()
  } else {
    remainder.to_string()
  }
}

///|
test "rfc850_compares_the_full_timestamp_to_the_fifty_year_window" {
  // The candidate year is exactly 50 years ahead, but the date is later in the
  // year than today, so the timestamp is more than 50 years in the future and
  // RFC 9110 requires resolving it to the most recent past year.
  let future_year = current_utc_year() + 50
  let value = "Sunday, 31-Dec-" + two_digit_year(future_year) + " 23:59:59 GMT"
  assert_eq(retry_after_millis(value), Some(0))
}

///|
test "fifty_year_cutoff_compares_the_whole_timestamp" {
  let (year, month, day, hour, minute, second) = current_utc_datetime()
  let cutoff_year = year + 50
  // A year beyond the cutoff is always more than 50 years in the future.
  assert_true(is_more_than_fifty_years_future(cutoff_year + 1, 1, 1, 0, 0, 0))
  assert_false(
    is_more_than_fifty_years_future(cutoff_year - 1, 12, 31, 23, 59, 59),
  )
  // A different day, hour or minute in the cutoff year decides the comparison
  // only when all earlier components are equal.
  let last_day = days_in_month(cutoff_year, month)
  let same_day = if day <= last_day { day } else { last_day }
  let other_day = if same_day < last_day { same_day + 1 } else { same_day - 1 }
  assert_eq(
    is_more_than_fifty_years_future(cutoff_year, month, other_day, 0, 0, 0),
    other_day > same_day,
  )
  let other_hour = if hour < 23 { hour + 1 } else { 0 }
  assert_eq(
    is_more_than_fifty_years_future(
      cutoff_year, month, same_day, other_hour, 0, 0,
    ),
    other_hour > hour,
  )
  let other_minute = if minute < 59 { minute + 1 } else { 0 }
  assert_eq(
    is_more_than_fifty_years_future(
      cutoff_year, month, same_day, hour, other_minute, 0,
    ),
    other_minute > minute,
  )
  let other_second = if second < 59 { second + 1 } else { 0 }
  assert_eq(
    is_more_than_fifty_years_future(
      cutoff_year, month, same_day, hour, minute, other_second,
    ),
    other_second > second,
  )
}
