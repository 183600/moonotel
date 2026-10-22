// Whitebox regression tests: decoding of `OTEL_EXPORTER_OTLP_HEADERS` values
// must tolerate unpaired UTF-16 surrogates instead of aborting.

///|
test "decode_header_value_replaces_unpaired_surrogates" {
  let lone = String::from_array([(0xD800).unsafe_to_char()])
  assert_eq(decode_header_value(lone + "%41"), "\u{FFFD}A")
}

///|
test "decode_header_value_keeps_valid_surrogate_pairs" {
  assert_eq(decode_header_value("\u{1F600}%41"), "\u{1F600}A")
}
