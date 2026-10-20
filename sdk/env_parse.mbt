// Parse an environment value as a non-negative decimal integer. The standard
// OTEL environment variables use decimal notation, so `parse_int`'s support
// for hexadecimal, octal, binary and digit separators must not leak through.

///|
fn parse_decimal_int(value : StringView) -> Int32? {
  let len = value.length()
  if len == 0 {
    return None
  }
  let mut number = 0
  let mut i = 0
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code < 0x30 || code > 0x39 {
      return None
    }
    let digit = code - 0x30
    if number > (2147483647 - digit) / 10 {
      return None
    }
    number = number * 10 + digit
    i = i + 1
  }
  Some(number)
}
