// Decodes OTLP/JSON `ExportTraceServiceResponse` bodies.
//
// The protobuf JSON mapping is accepted leniently: unknown fields (with any
// JSON value) are skipped, `rejectedSpans` may be a string or a number, and
// object members may carry optional whitespace. An empty body is a full
// success, exactly like the protobuf encoding. A `partialSuccess` field
// reports rejected spans; per the OTLP spec a partial success must not be
// retried.

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

// Parse a decimal integer, optionally signed. An optional leading `-` or `+`
// sign is accepted; no whitespace or other non-digit inside `value` is.

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
  } else if first == 0x2B {
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

// Parse a `rejectedSpans` value: either a JSON string holding a decimal
// integer (the canonical proto3 JSON form) or a bare JSON number.

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
    let mut cursor = pos
    while cursor < len {
      let code = text.unsafe_get(cursor).to_int()
      if (code >= 0x30 && code <= 0x39) || code == 0x2D || code == 0x2B {
        cursor = cursor + 1
      } else {
        break
      }
    }
    if cursor == pos {
      return None
    }
    match json_parse_decimal_int64(text[pos:cursor].to_owned()) {
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
    let after_key = match json_parse_string_at(text, cursor) {
      Some(pair) => pair.1
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
    match json_parse_string_at(text, pos) {
      Some(pair) => Some(pair.1)
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
    // A JSON number; the digits and exponent characters are consumed without
    // validation because the value is skipped.
    let mut cursor = pos
    while cursor < len {
      let c = text.unsafe_get(cursor).to_int()
      if (c >= 0x30 && c <= 0x39) ||
        c == 0x2D ||
        c == 0x2B ||
        c == 0x2E ||
        c == 0x65 ||
        c == 0x45 {
        cursor = cursor + 1
      } else {
        break
      }
    }
    Some(cursor)
  } else {
    None
  }
}

// Parse a `partialSuccess` message. Returns the rejected span count, the
// error message and the index just past the closing brace.

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
    let (key, after_key) = match json_parse_string_at(text, cursor) {
      Some(pair) => pair
      None => return None
    }
    cursor = json_skip_ws(text, after_key)
    if cursor >= len || text.unsafe_get(cursor).to_int() != 0x3A {
      return None
    }
    cursor = json_skip_ws(text, cursor + 1)
    if key == "rejectedSpans" {
      let (value, after) = match json_parse_rejected_spans(text, cursor) {
        Some(pair) => pair
        None => return None
      }
      rejected = value
      cursor = after
    } else if key == "errorMessage" {
      if cursor < len && text.unsafe_get(cursor).to_int() == 0x6E {
        // A JSON `null` is accepted for any field and means the default value.
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
    let (key, after_key) = match json_parse_string_at(text, pos) {
      Some(pair) => pair
      None => return malformed_json_response()
    }
    pos = json_skip_ws(text, after_key)
    if pos >= len || text.unsafe_get(pos).to_int() != 0x3A {
      return malformed_json_response()
    }
    pos = json_skip_ws(text, pos + 1)
    if key == "partialSuccess" {
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
