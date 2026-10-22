// Baggage values are percent-encoded so that reserved octets can travel in an
// HTTP header. Valid escapes must be decoded, and a decoded character that is
// legal in a value is written back literally while a reserved one is escaped
// again.

///|
test "baggage_decodes_an_escaped_character_that_is_legal_in_a_value" {
  let pairs = @propagation.parse_baggage("k=%41")
  assert_eq(pairs.length(), 1)
  assert_eq(pairs[0].0, "k")
  assert_eq(pairs[0].1, "A")
  // `A` is legal literally, so the normalized header does not keep `%41`.
  assert_eq(@propagation.format_baggage(pairs), "k=A")
}

///|
test "baggage_round_trips_reserved_characters_in_a_value" {
  let pairs = @propagation.parse_baggage("k=a%2Cb%3Bc%20d")
  assert_eq(pairs.length(), 1)
  assert_eq(pairs[0].1, "a,b;c d")
  assert_eq(@propagation.format_baggage(pairs), "k=a%2Cb%3Bc%20d")
}

///|
test "baggage_entries_decode_escaped_property_values" {
  let entries = @propagation.parse_baggage_entries("k=v;p=%41;q=a%2Cb")
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].value, "v")
  assert_eq(entries[0].properties.length(), 2)
  assert_eq(entries[0].properties[0].0, "p")
  assert_eq(entries[0].properties[0].1, "A")
  assert_eq(entries[0].properties[1].0, "q")
  assert_eq(entries[0].properties[1].1, "a,b")
  // A literal legal character is re-encoded as itself; the comma stays escaped.
  assert_eq(@propagation.format_baggage_entries(entries), "k=v;p=A;q=a%2Cb")
}

///|
test "baggage_percent_decoding_reports_the_normalized_length" {
  // `%41` decodes to the one-byte `A`, so it occupies one byte on the wire.
  assert_eq(@propagation.percent_encoded_length("A"), 1)
  assert_eq(@propagation.percent_decode("%41"), Some("A"))
  assert_eq(@propagation.percent_decode("a%2Cb"), Some("a,b"))
  assert_eq(@propagation.percent_decode("%"), None)
  assert_eq(@propagation.percent_decode("%4"), None)
  assert_eq(@propagation.percent_decode("%ZZ"), None)
}
