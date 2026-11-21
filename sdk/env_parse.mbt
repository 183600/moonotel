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

// Read a non-negative decimal integer from the environment variable `name`.
// An absent, blank, malformed or negative value yields `None`; surrounding
// whitespace is ignored.

///|
fn parse_env_non_negative_int(name : String) -> Int32? {
  match @env.get_env_var(name) {
    Some(value) => {
      let trimmed = value.trim()
      if trimmed == "" {
        None
      } else {
        parse_decimal_int(trimmed)
      }
    }
    None => None
  }
}

// Read a non-negative decimal integer from the environment variable `name`,
// falling back to `default` when the variable is absent, blank, malformed or
// negative.

///|
fn env_non_negative_int(name : String, default : Int32) -> Int32 {
  match parse_env_non_negative_int(name) {
    Some(value) => value
    None => default
  }
}

// Parse an environment value as a decimal floating-point number. `parse_double`
// accepts digit separators, which are not part of the decimal notation used by
// the standard OTEL environment variables, so reject them explicitly.

///|
fn parse_decimal_double(value : StringView) -> Double? {
  let len = value.length()
  let mut i = 0
  while i < len {
    if value.unsafe_get(i) == '_' {
      return None
    }
    i = i + 1
  }
  let parsed = @string.parse_double(value) catch { _ => return None }
  Some(parsed)
}
