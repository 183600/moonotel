// White-box tests for the surrogate sanitizer used on captured request header
// values. Well-formed pairs must be preserved while unpaired halves are
// replaced with U+FFFD.

///|
test "sanitize_utf16_surrogates preserves well-formed pairs" {
  let pair = String::from_array([
    (0xD83D).unsafe_to_char(),
    (0xDE00).unsafe_to_char(),
  ])
  assert_eq(sanitize_utf16_surrogates(pair), pair)
}

///|
test "sanitize_utf16_surrogates replaces unpaired halves around a pair" {
  let high = (0xD800).unsafe_to_char().to_string()
  let low = (0xDC00).unsafe_to_char().to_string()
  let pair = String::from_array([
    (0xD83D).unsafe_to_char(),
    (0xDE00).unsafe_to_char(),
  ])
  let replacement = (0xFFFD).unsafe_to_char().to_string()
  let value = pair + high + "x" + low
  assert_eq(
    sanitize_utf16_surrogates(value),
    pair + replacement + "x" + replacement,
  )
}
