// Decodes OTLP/JSON `ExportTraceServiceResponse` bodies.
//
// The protobuf JSON mapping is accepted leniently: unknown fields (with any
// JSON value) are skipped, `rejectedSpans` may be a string, a number or a
// number in exponent/decimal form, and object members may use either the
// lowerCamelCase name or the original proto field name. Object members may
// carry optional whitespace. An empty body is a full success, exactly like
// the protobuf encoding. A `partialSuccess` field reports rejected spans; per
// the OTLP spec a partial success must not be retried.

///|
fn malformed_json_response() -> @sdk.ExportResult {
  @sdk.ExportFailure("malformed OTLP response body")
}

///|
fn json_is_ws_code(code : Int32) -> Bool {
  code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D
}

///|
fn json_skip_ws(text : String, start : Int32) -> Int32 {
  let len = text.length()
  let mut pos = start
  while pos < len && json_is_ws_code(text.unsafe_get(pos).to_int()) {
    pos = pos + 1
  }
  pos
}

///|
fn json_hex_nibble(code : Int32) -> Int32 {
  if code >= 0x30 && code <= 0x39 {
    code - 0x30
  } else if code >= 0x41 && code <= 0x46 {
    code - 0x37
  } else if code >= 0x61 && code <= 0x66 {
    code - 0x57
  } else {
    -1
  }
}

// Compare a plain JSON string body (without escapes) to `expected`.

///|
fn json_string_range_equals(
  text : String,
  start : Int32,
  end : Int32,
  expected : String,
) -> Bool {
  if end - start != expected.length() {
    return false
  }
  let mut i = start
  let mut j = 0
  while i < end {
    if text.unsafe_get(i) != expected.unsafe_get(j) {
      return false
    }
    i = i + 1
    j = j + 1
  }
  true
}

// Classify the JSON string at `start` against two fields, each accepted under
// two names. Returns `(0, after)` for the first field, `(1, after)` for the
// second and `(-1, after)` for any other value. Plain strings are compared in
// place; strings containing escapes fall back to the decoder so that escaped
// and unescaped field names remain equivalent.

///|
fn json_field_id_at(
  text : String,
  start : Int32,
  first_json : String,
  first_proto : String,
  second_json : String,
  second_proto : String,
) -> (Int32, Int32)? {
  let len = text.length()
  if start >= len || text.unsafe_get(start).to_int() != 0x22 {
    return None
  }
  let content_start = start + 1
  let mut pos = content_start
  while pos < len {
    let code = text.unsafe_get(pos).to_int()
    if code == 0x22 {
      let id = if json_string_range_equals(text, content_start, pos, first_json) ||
        json_string_range_equals(text, content_start, pos, first_proto) {
        0
      } else if json_string_range_equals(
        text,
        content_start,
        pos,
        second_json,
      ) || json_string_range_equals(text, content_start, pos, second_proto) {
        1
      } else {
        -1
      }
      return Some((id, pos + 1))
    }
    if code == 0x5C || code < 0x20 {
      break
    }
    pos = pos + 1
  }
  if pos >= len {
    return None
  }
  let (decoded, after) = match json_parse_string_at(text, start) {
    Some(pair) => pair
    None => return None
  }
  let id = if decoded == first_json || decoded == first_proto {
    0
  } else if decoded == second_json || decoded == second_proto {
    1
  } else {
    -1
  }
  Some((id, after))
}

// Validate and skip the JSON string starting at `start`, returning the index
// just past the closing quote.

///|
fn json_skip_string_at(text : String, start : Int32) -> Int32? {
  let len = text.length()
  if start >= len || text.unsafe_get(start).to_int() != 0x22 {
    return None
  }
  let mut pos = start + 1
  while pos < len {
    let code = text.unsafe_get(pos).to_int()
    if code == 0x22 {
      return Some(pos + 1)
    }
    if code == 0x5C || code < 0x20 {
      break
    }
    pos = pos + 1
  }
  if pos >= len {
    return None
  }
  match json_parse_string_at(text, start) {
    Some((_, after)) => Some(after)
    None => None
  }
}

// Parse the JSON string starting at the opening quote. Returns the decoded
// text and the index just past the closing quote.

///|
fn json_parse_string_at(text : String, start : Int32) -> (String, Int32)? {
  let len = text.length()
  if start >= len || text.unsafe_get(start).to_int() != 0x22 {
    return None
  }
  // Most response field names and messages contain no escapes or control
  // characters; such strings are copied as a single slice.
  let mut pos = start + 1
  while pos < len {
    let code = text.unsafe_get(pos).to_int()
    if code == 0x22 {
      return Some((text[start + 1:pos].to_owned(), pos + 1))
    }
    if code == 0x5C || code < 0x20 {
      break
    }
    pos = pos + 1
  }
  if pos >= len {
    return None
  }
  let sb = StringBuilder()
  sb.write_stringview(text.view(start_offset=start + 1, end_offset=pos))
  while pos < len {
    let code = text.unsafe_get(pos).to_int()
    if code == 0x22 {
      return Some((sb.to_string(), pos + 1))
    }
    if code != 0x5C {
      // Unescaped control characters are not legal in JSON strings.
      if code < 0x20 {
        return None
      }
      sb.write_char(code.unsafe_to_char())
      pos = pos + 1
      continue
    }
    pos = pos + 1
    if pos >= len {
      return None
    }
    let escaped = text.unsafe_get(pos).to_int()
    if escaped == 0x75 {
      // `\uXXXX`, possibly the high half of a surrogate pair.
      if pos + 4 >= len {
        return None
      }
      let h0 = json_hex_nibble(text.unsafe_get(pos + 1).to_int())
      let h1 = json_hex_nibble(text.unsafe_get(pos + 2).to_int())
      let h2 = json_hex_nibble(text.unsafe_get(pos + 3).to_int())
      let h3 = json_hex_nibble(text.unsafe_get(pos + 4).to_int())
      if h0 < 0 || h1 < 0 || h2 < 0 || h3 < 0 {
        return None
      }
      let unit = h0 * 4096 + h1 * 256 + h2 * 16 + h3
      pos = pos + 5
      if unit >= 0xD800 &&
        unit <= 0xDBFF &&
        pos + 5 < len &&
        text.unsafe_get(pos).to_int() == 0x5C &&
        text.unsafe_get(pos + 1).to_int() == 0x75 {
        let l0 = json_hex_nibble(text.unsafe_get(pos + 2).to_int())
        let l1 = json_hex_nibble(text.unsafe_get(pos + 3).to_int())
        let l2 = json_hex_nibble(text.unsafe_get(pos + 4).to_int())
        let l3 = json_hex_nibble(text.unsafe_get(pos + 5).to_int())
        if l0 >= 0 && l1 >= 0 && l2 >= 0 && l3 >= 0 {
          let low = l0 * 4096 + l1 * 256 + l2 * 16 + l3
          if low >= 0xDC00 && low <= 0xDFFF {
            let point = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
            sb.write_char(point.unsafe_to_char())
            pos = pos + 6
            continue
          }
        }
      }
      if unit >= 0xD800 && unit <= 0xDFFF {
        // A lone surrogate has no scalar value; substitute U+FFFD.
        sb.write_char((0xFFFD).unsafe_to_char())
      } else {
        sb.write_char(unit.unsafe_to_char())
      }
      continue
    }
    let decoded = match escaped {
      0x22 => '"'
      0x5C => '\\'
      0x2F => '/'
      0x62 => (0x08).unsafe_to_char()
      0x66 => (0x0C).unsafe_to_char()
      0x6E => '\n'
      0x72 => '\r'
      0x74 => '\t'
      _ => return None
    }
    sb.write_char(decoded)
    pos = pos + 1
  }
  None
}

// Parse a decimal integer. Only an optional leading `-` sign is accepted
// (matching the JSON number grammar and the proto3 JSON decimal-string form);
// a leading `+` or any other non-digit inside `value` is rejected.

///|
fn json_parse_decimal_int64(value : String) -> Int64? {
  let len = value.length()
  if len == 0 {
    return None
  }
  let mut pos = 0
  let mut negative = false
  let first = value.unsafe_get(0).to_int()
  if first == 0x2D {
    negative = true
    pos = 1
  }
  if pos >= len {
    return None
  }
  let mut magnitude : UInt64 = 0
  while pos < len {
    let code = value.unsafe_get(pos).to_int()
    if code < 0x30 || code > 0x39 {
      return None
    }
    let digit = (code - 0x30).to_uint64()
    if magnitude > (18446744073709551615UL - digit) / 10UL {
      // `magnitude * 10 + digit` would wrap around.
      return None
    }
    magnitude = magnitude * 10UL + digit
    pos = pos + 1
  }
  if negative {
    if magnitude > 9223372036854775808UL {
      return None
    }
    Some((0UL - magnitude).reinterpret_as_int64())
  } else {
    if magnitude > 9223372036854775807UL {
      return None
    }
    Some(magnitude.reinterpret_as_int64())
  }
}

///|
fn json_normalize_numeric_int64(token : String) -> String? {
  let len = token.length()
  if len == 0 {
    return None
  }
  let mut pos = 0
  let mut negative = false
  let first = token.unsafe_get(0).to_int()
  if first == 0x2D {
    negative = true
    pos = 1
  }
  if pos >= len {
    return None
  }
  let digits = StringBuilder()
  let mut integer_digits = 0
  while pos < len {
    let code = token.unsafe_get(pos).to_int()
    if code < 0x30 || code > 0x39 {
      break
    }
    digits.write_char(code.unsafe_to_char())
    integer_digits = integer_digits + 1
    pos = pos + 1
  }
  if integer_digits == 0 {
    return None
  }
  let mut fraction_digits = 0
  if pos < len && token.unsafe_get(pos).to_int() == 0x2E {
    pos = pos + 1
    let fraction_start = pos
    while pos < len {
      let code = token.unsafe_get(pos).to_int()
      if code < 0x30 || code > 0x39 {
        break
      }
      digits.write_char(code.unsafe_to_char())
      fraction_digits = fraction_digits + 1
      pos = pos + 1
    }
    if pos == fraction_start {
      return None
    }
  }
  let mut exponent : Int64 = 0L
  if pos < len {
    let marker = token.unsafe_get(pos).to_int()
    if marker == 0x65 || marker == 0x45 {
      pos = pos + 1
      let mut exponent_negative = false
      if pos < len {
        let sign = token.unsafe_get(pos).to_int()
        if sign == 0x2D {
          exponent_negative = true
          pos = pos + 1
        } else if sign == 0x2B {
          pos = pos + 1
        }
      }
      if pos >= len {
        return None
      }
      let exponent_start = pos
      let mut value : Int64 = 0L
      while pos < len {
        let code = token.unsafe_get(pos).to_int()
        if code < 0x30 || code > 0x39 {
          break
        }
        if value < 1000000L {
          value = value * 10L + (code - 0x30).to_int64()
        }
        pos = pos + 1
      }
      if pos == exponent_start {
        return None
      }
      exponent = if exponent_negative { -value } else { value }
    }
  }
  if pos != len {
    return None
  }
  let digit_string = digits.to_string()
  let digit_length = digit_string.length()
  let mut start = 0
  while start < digit_length && digit_string.unsafe_get(start).to_int() == 0x30 {
    start = start + 1
  }
  if start == digit_length {
    return Some("0")
  }
  let mut end = digit_length
  let mut exponent_10 = exponent - fraction_digits.to_int64()
  if exponent_10 < 0L {
    let needed = -exponent_10
    if needed > (end - start).to_int64() {
      return None
    }
    let keep = end - needed.to_int()
    let mut i = keep
    while i < end {
      if digit_string.unsafe_get(i).to_int() != 0x30 {
        return None
      }
      i = i + 1
    }
    end = keep
    if end == start {
      return None
    }
    exponent_10 = 0L
  }
  let total_length = (end - start).to_int64() + exponent_10
  if total_length > 19L {
    return None
  }
  let normalized = StringBuilder()
  if negative {
    normalized.write_char('-')
  }
  let mut i = start
  while i < end {
    normalized.write_char(digit_string.unsafe_get(i).unsafe_to_char())
    i = i + 1
  }
  let mut zeros = exponent_10
  while zeros > 0L {
    normalized.write_char('0')
    zeros = zeros - 1L
  }
  Some(normalized.to_string())
}

// Parse an int64 field that arrives as a bare JSON number. Integers are
// accepted directly; exponent/decimal forms (`2e2`, `2.0`) are accepted when
// they denote a whole number, matching the goog.protobuf JSON parser.

///|
fn json_parse_numeric_int64(token : String) -> Int64? {
  match json_parse_decimal_int64(token) {
    Some(value) => Some(value)
    None =>
      match json_normalize_numeric_int64(token) {
        Some(normalized) => json_parse_decimal_int64(normalized)
        None => None
      }
  }
}

// Parse a `rejectedSpans` value: either a JSON string holding a decimal
// integer (the canonical proto3 JSON form) or a bare JSON number. `null`
// means the default value (zero).

///|
fn json_parse_rejected_spans(text : String, start : Int32) -> (Int64, Int32)? {
  let len = text.length()
  let pos = json_skip_ws(text, start)
  if pos >= len {
    return None
  }
  if text.unsafe_get(pos).to_int() == 0x6E {
    // A JSON `null` is accepted for any field and means the default value.
    match json_skip_value(text, pos, 0) {
      Some(after) => return Some((0L, after))
      None => return None
    }
  }
  if text.unsafe_get(pos).to_int() == 0x22 {
    let (raw, after) = match json_parse_string_at(text, pos) {
      Some(pair) => pair
      None => return None
    }
    match json_parse_decimal_int64(raw) {
      Some(value) => Some((value, after))
      None => None
    }
  } else {
    // A bare JSON number: validate it against the RFC 8259 grammar with the
    // same strictness applied to numbers in skipped fields.
    let cursor = match json_skip_number(text, pos) {
      Some(end) => end
      None => return None
    }
    match json_parse_numeric_int64(text[pos:cursor].to_owned()) {
      Some(value) => Some((value, cursor))
      None => None
    }
  }
}

// Skip a JSON object. `pos` points at the opening brace; returns the index
// just past the closing brace.

///|
fn json_skip_object(text : String, pos : Int32, depth : Int32) -> Int32? {
  let len = text.length()
  let mut cursor = json_skip_ws(text, pos + 1)
  if cursor < len && text.unsafe_get(cursor).to_int() == 0x7D {
    return Some(cursor + 1)
  }
  while true {
    let after_key = match json_skip_string_at(text, cursor) {
      Some(after) => after
      None => return None
    }
    cursor = json_skip_ws(text, after_key)
    if cursor >= len || text.unsafe_get(cursor).to_int() != 0x3A {
      return None
    }
    cursor = match json_skip_value(text, cursor + 1, depth + 1) {
      Some(end) => end
      None => return None
    }
    cursor = json_skip_ws(text, cursor)
    if cursor >= len {
      return None
    }
    let code = text.unsafe_get(cursor).to_int()
    if code == 0x7D {
      return Some(cursor + 1)
    }
    if code != 0x2C {
      return None
    }
    cursor = json_skip_ws(text, cursor + 1)
    if cursor >= len {
      return None
    }
  } nobreak {
    None
  }
}

// Skip a JSON array. `pos` points at the opening bracket.

///|
fn json_skip_array(text : String, pos : Int32, depth : Int32) -> Int32? {
  let len = text.length()
  let mut cursor = json_skip_ws(text, pos + 1)
  if cursor < len && text.unsafe_get(cursor).to_int() == 0x5D {
    return Some(cursor + 1)
  }
  while true {
    cursor = match json_skip_value(text, cursor, depth + 1) {
      Some(end) => end
      None => return None
    }
    cursor = json_skip_ws(text, cursor)
    if cursor >= len {
      return None
    }
    let code = text.unsafe_get(cursor).to_int()
    if code == 0x5D {
      return Some(cursor + 1)
    }
    if code != 0x2C {
      return None
    }
    cursor = json_skip_ws(text, cursor + 1)
    if cursor >= len {
      return None
    }
  } nobreak {
    None
  }
}

// Skip a JSON number, validating it against the RFC 8259 grammar:
// `-? (0 / [1-9][0-9]*) (. [0-9]+)? ([eE] [+-]? [0-9]+)?`.

///|
fn json_skip_number(text : String, start : Int32) -> Int32? {
  let len = text.length()
  let mut pos = start
  if pos < len && text.unsafe_get(pos).to_int() == 0x2D {
    pos = pos + 1
  }
  if pos >= len {
    return None
  }
  let first = text.unsafe_get(pos).to_int()
  if first == 0x30 {
    pos = pos + 1
  } else if first >= 0x31 && first <= 0x39 {
    pos = pos + 1
    while pos < len &&
      text.unsafe_get(pos).to_int() >= 0x30 &&
      text.unsafe_get(pos).to_int() <= 0x39 {
      pos = pos + 1
    }
  } else {
    return None
  }
  if pos < len && text.unsafe_get(pos).to_int() == 0x2E {
    pos = pos + 1
    let fraction_start = pos
    while pos < len &&
      text.unsafe_get(pos).to_int() >= 0x30 &&
      text.unsafe_get(pos).to_int() <= 0x39 {
      pos = pos + 1
    }
    if pos == fraction_start {
      return None
    }
  }
  if pos < len {
    let exponent = text.unsafe_get(pos).to_int()
    if exponent == 0x65 || exponent == 0x45 {
      pos = pos + 1
      if pos < len {
        let sign = text.unsafe_get(pos).to_int()
        if sign == 0x2B || sign == 0x2D {
          pos = pos + 1
        }
      }
      let exponent_start = pos
      while pos < len &&
        text.unsafe_get(pos).to_int() >= 0x30 &&
        text.unsafe_get(pos).to_int() <= 0x39 {
        pos = pos + 1
      }
      if pos == exponent_start {
        return None
      }
    }
  }
  Some(pos)
}

// Skip any JSON value. `start` may point at leading whitespace. The depth
// bound keeps deeply nested input from exhausting the stack.

///|
fn json_skip_value(text : String, start : Int32, depth : Int32) -> Int32? {
  if depth > 64 {
    return None
  }
  let len = text.length()
  let pos = json_skip_ws(text, start)
  if pos >= len {
    return None
  }
  let code = text.unsafe_get(pos).to_int()
  if code == 0x22 {
    match json_skip_string_at(text, pos) {
      Some(after) => Some(after)
      None => None
    }
  } else if code == 0x7B {
    json_skip_object(text, pos, depth)
  } else if code == 0x5B {
    json_skip_array(text, pos, depth)
  } else if code == 0x74 {
    // true
    if pos + 4 <= len &&
      text.unsafe_get(pos + 1).to_int() == 0x72 &&
      text.unsafe_get(pos + 2).to_int() == 0x75 &&
      text.unsafe_get(pos + 3).to_int() == 0x65 {
      Some(pos + 4)
    } else {
      None
    }
  } else if code == 0x66 {
    // false
    if pos + 5 <= len &&
      text.unsafe_get(pos + 1).to_int() == 0x61 &&
      text.unsafe_get(pos + 2).to_int() == 0x6C &&
      text.unsafe_get(pos + 3).to_int() == 0x73 &&
      text.unsafe_get(pos + 4).to_int() == 0x65 {
      Some(pos + 5)
    } else {
      None
    }
  } else if code == 0x6E {
    // null
    if pos + 4 <= len &&
      text.unsafe_get(pos + 1).to_int() == 0x75 &&
      text.unsafe_get(pos + 2).to_int() == 0x6C &&
      text.unsafe_get(pos + 3).to_int() == 0x6C {
      Some(pos + 4)
    } else {
      None
    }
  } else if code == 0x2D || (code >= 0x30 && code <= 0x39) {
    json_skip_number(text, pos)
  } else {
    None
  }
}

// Parse a `partialSuccess` (`partial_success`) message. Returns the rejected
// span count, the error message and the index just past the closing brace.

///|
fn json_parse_partial_success(
  text : String,
  start : Int32,
) -> (Int64, String, Int32)? {
  let len = text.length()
  let at = json_skip_ws(text, start)
  if at >= len {
    return None
  }
  if text.unsafe_get(at).to_int() == 0x6E {
    // A JSON `null` is accepted for any field and means the default value,
    // i.e. an empty partial-success message.
    match json_skip_value(text, at, 0) {
      Some(after) => return Some((0L, "", after))
      None => return None
    }
  }
  if text.unsafe_get(at).to_int() != 0x7B {
    return None
  }
  let mut cursor = json_skip_ws(text, at + 1)
  if cursor < len && text.unsafe_get(cursor).to_int() == 0x7D {
    return Some((0L, "", cursor + 1))
  }
  let mut rejected : Int64 = 0L
  let mut message = ""
  while true {
    let (key, after_key) = match json_field_id_at(
      text,
      cursor,
      "rejectedSpans",
      "rejected_spans",
      "errorMessage",
      "error_message",
    ) {
      Some(pair) => pair
      None => return None
    }
    cursor = json_skip_ws(text, after_key)
    if cursor >= len || text.unsafe_get(cursor).to_int() != 0x3A {
      return None
    }
    cursor = json_skip_ws(text, cursor + 1)
    if key == 0 {
      let (value, after) = match json_parse_rejected_spans(text, cursor) {
        Some(pair) => pair
        None => return None
      }
      rejected = value
      cursor = after
    } else if key == 1 {
      if cursor < len && text.unsafe_get(cursor).to_int() == 0x6E {
        // A JSON `null` is accepted for any field and means the default value.
        message = ""
        cursor = match json_skip_value(text, cursor, 0) {
          Some(end) => end
          None => return None
        }
      } else {
        let (value, after) = match json_parse_string_at(text, cursor) {
          Some(pair) => pair
          None => return None
        }
        message = value
        cursor = after
      }
    } else {
      cursor = match json_skip_value(text, cursor, 0) {
        Some(end) => end
        None => return None
      }
    }
    cursor = json_skip_ws(text, cursor)
    if cursor >= len {
      return None
    }
    let code = text.unsafe_get(cursor).to_int()
    if code == 0x7D {
      return Some((rejected, message, cursor + 1))
    }
    if code != 0x2C {
      return None
    }
    cursor = json_skip_ws(text, cursor + 1)
    if cursor >= len {
      return None
    }
  } nobreak {
    None
  }
}

// Interpret an OTLP/JSON `ExportTraceServiceResponse` body. Truncated or
// otherwise malformed bodies are reported as failures.

///|
pub fn decode_export_response_json(body : Bytes) -> @sdk.ExportResult {
  // The OTLP specification requires a response body size limit (4 MiB by
  // recommendation) to be enforced before parsing.
  if body.length() > OTLP_MAX_RESPONSE_BODY_BYTES {
    return oversized_response()
  }
  let text = @utf8.decode_lossy(body.exact_view())
  let len = text.length()
  let mut pos = json_skip_ws(text, 0)
  if pos >= len {
    return @sdk.ExportSuccess
  }
  if text.unsafe_get(pos).to_int() != 0x7B {
    return malformed_json_response()
  }
  pos = json_skip_ws(text, pos + 1)
  if pos < len && text.unsafe_get(pos).to_int() == 0x7D {
    pos = json_skip_ws(text, pos + 1)
    if pos == len {
      return @sdk.ExportSuccess
    }
    return malformed_json_response()
  }
  let mut rejected : Int64 = 0L
  let mut message = ""
  while true {
    let (key, after_key) = match json_field_id_at(
      text,
      pos,
      "partialSuccess",
      "partial_success",
      "",
      "",
    ) {
      Some(pair) => pair
      None => return malformed_json_response()
    }
    pos = json_skip_ws(text, after_key)
    if pos >= len || text.unsafe_get(pos).to_int() != 0x3A {
      return malformed_json_response()
    }
    pos = json_skip_ws(text, pos + 1)
    if key == 0 {
      let (count, text_message, after) = match
        json_parse_partial_success(text, pos) {
        Some(triple) => triple
        None => return malformed_json_response()
      }
      rejected = count
      message = text_message
      pos = after
    } else {
      pos = match json_skip_value(text, pos, 0) {
        Some(end) => end
        None => return malformed_json_response()
      }
    }
    pos = json_skip_ws(text, pos)
    if pos >= len {
      return malformed_json_response()
    }
    let code = text.unsafe_get(pos).to_int()
    if code == 0x7D {
      pos = pos + 1
      break
    }
    if code != 0x2C {
      return malformed_json_response()
    }
    pos = json_skip_ws(text, pos + 1)
    if pos >= len {
      return malformed_json_response()
    }
  }
  pos = json_skip_ws(text, pos)
  if pos != len {
    return malformed_json_response()
  }
  if rejected != 0 || message != "" {
    @sdk.ExportFailure(
      "partial success: rejected " +
      rejected.to_string() +
      " span(s) " +
      message,
    )
  } else {
    @sdk.ExportSuccess
  }
}
