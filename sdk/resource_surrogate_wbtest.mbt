// Whitebox regression tests: percent-decoding of resource attribute values
// must tolerate unpaired UTF-16 surrogates instead of aborting.

///|
test "decode_percent_replaces_unpaired_surrogates" {
  let lone = String::from_array([(0xD800).unsafe_to_char()])
  assert_eq(decode_percent(lone + "%41"), "\u{FFFD}A")
}

///|
test "decode_percent_keeps_valid_surrogate_pairs" {
  assert_eq(decode_percent("\u{1F600}%41"), "\u{1F600}A")
}

///|
test "decode_percent_keeps_pairs_while_replacing_unpaired_surrogates" {
  let lone_high = String::from_array([(0xD800).unsafe_to_char()])
  let lone_low = String::from_array([(0xDC00).unsafe_to_char()])
  assert_eq(
    decode_percent("\u{1F600}" + lone_high + "\u{1F600}%41"),
    "\u{1F600}\u{FFFD}\u{1F600}A",
  )
  assert_eq(
    decode_percent("\u{1F600}" + lone_low + "%41"),
    "\u{1F600}\u{FFFD}A",
  )
}
