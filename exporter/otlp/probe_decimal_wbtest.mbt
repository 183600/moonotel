// Temporary probe for the decimal-digit writer.

///|
test "probe json decimal digits" {
  let cases : Array[UInt64] = [
    0UL,
    1UL,
    9UL,
    10UL,
    99UL,
    100UL,
    101UL,
    999UL,
    1000UL,
    1000000000000000000UL,
    9999999999999999999UL,
    10000000000000000000UL,
    12345678901234567890UL,
    18446744073709551615UL,
  ]
  for v in cases {
    let sb = JsonBuf::new(1)
    json_write_decimal_digits(sb, v)
    let out = @utf8.decode_lossy(sb.to_bytes().exact_view())
    assert_eq(out, v.to_string())
  }
}
