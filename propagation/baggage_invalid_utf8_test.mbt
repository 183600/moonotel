// W3C Baggage requires percent-decoded octets that are not valid UTF-8 to be
// replaced with U+FFFD. Re-encoding the result must escape the replacement
// character rather than letting the malformed input through.

///|
test "percent_decode_replaces_invalid_utf8_with_the_replacement_character" {
  assert_eq(@propagation.percent_decode("a%C3b"), Some("a\u{FFFD}b"))
  assert_eq(@propagation.percent_decode("%80"), Some("\u{FFFD}"))
}

///|
test "invalid_utf8_round_trips_through_format_baggage" {
  let pairs = @propagation.parse_baggage("k=a%C3b")
  assert_eq(pairs, [("k", "a\u{FFFD}b")])
  let formatted = @propagation.format_baggage(pairs)
  assert_eq(formatted, "k=a%EF%BF%BDb")
  assert_eq(@propagation.parse_baggage(formatted), pairs)
}
