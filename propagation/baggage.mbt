// W3C Baggage propagator for the `baggage` header.
//
// `baggage` layout: a comma-separated list of `key=value` members, where each
// member may carry `;`-separated properties. Keys are HTTP tokens; values are
// percent-encoded so that any octet can be represented. Parsing is lenient:
// members with a malformed key, value or encoding are dropped, while the
// remaining members are kept.
//
// Properties (`key=value;prop=1`) are accepted but not surfaced; the MVP only
// propagates the key/value pairs.

// Name of the `baggage` header

///|
pub fn baggage_header_name() -> String {
  "baggage"
}

// Maximum number of members propagated in one `baggage` header. The W3C
// Baggage specification requires a platform to propagate at most 64 members;
// beyond that limit members may be dropped.

///|
pub const BAGGAGE_MAX_MEMBERS : Int32 = 64

// Maximum size in bytes of a `baggage` header. The W3C Baggage specification
// requires a platform to propagate at most 8192 bytes; beyond that limit
// members may be dropped.

///|
pub const BAGGAGE_MAX_BYTES : Int32 = 8192

// Whether each ASCII code unit (0-127) is an HTTP token character.

///|
let token_char_table : FixedArray[Bool] = build_token_char_table()

///|
fn build_token_char_table() -> FixedArray[Bool] {
  let table : FixedArray[Bool] = FixedArray::make(128, false)
  let mut code = 0
  while code < 128 {
    let is_token = if (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) {
      true
    } else {
      match code {
        0x21
        | 0x23
        | 0x24
        | 0x25
        | 0x26
        | 0x27
        | 0x2A
        | 0x2B
        | 0x2D
        | 0x2E
        | 0x5E
        | 0x5F
        | 0x60
        | 0x7C
        | 0x7E => true
        _ => false
      }
    }
    table.unsafe_set(code, is_token)
    code = code + 1
  }
  table
}

///|
fn is_token_char(c : Char) -> Bool {
  let code = c.to_int()
  code >= 0 && code < 128 && token_char_table.unsafe_get(code)
}

///|
fn is_valid_baggage_key(key : StringView) -> Bool {
  let len = key.length()
  if len == 0 {
    return false
  }
  let mut i = 0
  while i < len {
    if !is_token_char(key.unsafe_get(i).unsafe_to_char()) {
      return false
    }
    i = i + 1
  }
  true
}

// Whether each ASCII code unit (0-127) may appear literally in a baggage
// value. Percent-encoding is required for everything else (including `"`,
// `%`, `,`, `;` and `\`).

///|
let baggage_value_char_table : FixedArray[Bool] = build_baggage_value_char_table()

///|
fn build_baggage_value_char_table() -> FixedArray[Bool] {
  let table : FixedArray[Bool] = FixedArray::make(128, false)
  let mut code = 0
  while code < 128 {
    let allowed = code == 0x21 ||
      (code >= 0x23 && code <= 0x2B && code != 0x25) ||
      (code >= 0x2D && code <= 0x3A) ||
      (code >= 0x3C && code <= 0x5B) ||
      (code >= 0x5D && code <= 0x7E)
    table.unsafe_set(code, allowed)
    code = code + 1
  }
  table
}

// Whether a byte may appear literally in a baggage value.

///|
fn is_baggage_value_char(code : Int32) -> Bool {
  code >= 0 && code < 128 && baggage_value_char_table.unsafe_get(code)
}

// Decode the body of a baggage value that contains at least one `%`.
// Alongside the decoded string, the byte length of its percent-encoded form is
// reported, so that callers do not have to scan the decoded value again. In
// the non-ASCII case (where lossy UTF-8 decoding makes the byte accounting
// hard to track) the length is recomputed from the decoded string to stay
// exactly equivalent to `percent_encoded_length`.

///|
fn percent_decode_escaped_with_length(
  value : StringView,
) -> (String, Int32)? {
  let len = value.length()
  let mut decoded_len = 0
  let mut encoded_len = 0
  let mut ascii = true
  let mut i = 0
  while i < len {
    let c = value.unsafe_get(i).unsafe_to_char()
    if c == '%' {
      if i + 2 >= len {
        return None
      }
      let hi = hex_digit_value(value.unsafe_get(i + 1).unsafe_to_char())
      let lo = hex_digit_value(value.unsafe_get(i + 2).unsafe_to_char())
      if hi < 0 || lo < 0 {
        return None
      }
      let byte = hi * 16 + lo
      if byte >= 0x80 {
        ascii = false
        encoded_len = encoded_len + 3
      } else if is_baggage_value_char(byte) {
        encoded_len = encoded_len + 1
      } else {
        encoded_len = encoded_len + 3
      }
      decoded_len = decoded_len + 1
      i = i + 3
    } else {
      let code = c.to_int()
      if !is_baggage_value_char(code) {
        return None
      }
      encoded_len = encoded_len + 1
      decoded_len = decoded_len + 1
      i = i + 1
    }
  }
  if ascii {
    let out = FixedArray::make(decoded_len * 2, b'\x00')
    let mut j = 0
    let mut pos = 0
    while j < len {
      let c = value.unsafe_get(j).unsafe_to_char()
      if c == '%' {
        let hi = hex_digit_value(value.unsafe_get(j + 1).unsafe_to_char())
        let lo = hex_digit_value(value.unsafe_get(j + 2).unsafe_to_char())
        out.unsafe_set(pos * 2, (hi * 16 + lo).to_byte())
        pos = pos + 1
        j = j + 3
      } else {
        out.unsafe_set(pos * 2, c.to_int().to_byte())
        pos = pos + 1
        j = j + 1
      }
    }
    Some((out.unsafe_reinterpret_as_bytes().to_unchecked_string(), encoded_len))
  } else {
    let out = FixedArray::make(decoded_len, b'\x00')
    let mut j = 0
    let mut pos = 0
    while j < len {
      let c = value.unsafe_get(j).unsafe_to_char()
      if c == '%' {
        let hi = hex_digit_value(value.unsafe_get(j + 1).unsafe_to_char())
        let lo = hex_digit_value(value.unsafe_get(j + 2).unsafe_to_char())
        out.unsafe_set(pos, (hi * 16 + lo).to_byte())
        pos = pos + 1
        j = j + 3
      } else {
        out.unsafe_set(pos, c.to_int().to_byte())
        pos = pos + 1
        j = j + 1
      }
    }
    let decoded = @utf8.decode_lossy(
      out.unsafe_reinterpret_as_bytes().exact_view(),
    )
    Some((decoded, percent_encoded_length(decoded)))
  }
}

// Decode the body of a baggage value that contains at least one `%`.

///|
fn percent_decode_escaped(value : StringView) -> String? {
  match percent_decode_escaped_with_length(value) {
    Some((decoded, _)) => Some(decoded)
    None => None
  }
}

// Percent-decode a baggage value held as a view, also reporting the byte
// length of its percent-encoded form. Returns None when a `%` sequence is
// truncated or not followed by two hex digits.

///|
fn percent_decode_view_with_length(
  value : StringView,
) -> (String, Int32)? {
  let len = value.length()
  // A value without `%` decodes to itself; its characters still need
  // validating. Every kept character is allowed literally, so the encoded
  // length equals the number of characters.
  let mut i = 0
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code == 0x25 {
      break
    }
    if !is_baggage_value_char(code) {
      return None
    }
    i = i + 1
  }
  if i == len {
    return Some((value.to_owned(), len))
  }
  percent_decode_escaped_with_length(value)
}

// Percent-decode a baggage value. Returns None when a `%` sequence is
// truncated or not followed by two hex digits.

///|
pub fn percent_decode(value : String) -> String? {
  let len = value.length()
  // A value without `%` decodes to itself; its characters still need
  // validating.
  let mut i = 0
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code == 0x25 {
      break
    }
    if !is_baggage_value_char(code) {
      return None
    }
    i = i + 1
  }
  if i == len {
    return Some(value)
  }
  percent_decode_escaped(value[:])
}

// Upper-case hex ASCII byte of every nibble value 0-15.

///|
let hex_ascii_upper_bytes : FixedArray[Byte] = build_hex_ascii_upper_bytes()

///|
fn build_hex_ascii_upper_bytes() -> FixedArray[Byte] {
  let table : FixedArray[Byte] = FixedArray::make(16, b'0')
  let mut i = 0
  while i < 16 {
    table.unsafe_set(i, (if i < 10 { i + 48 } else { i + 55 }).to_byte())
    i = i + 1
  }
  table
}

///|
fn upper_hex_byte(value : Int32) -> Byte {
  if value >= 0 && value < 16 {
    hex_ascii_upper_bytes.unsafe_get(value)
  } else {
    b'0'
  }
}

// Write the percent-encoded form of `value` into the UTF-16LE byte buffer
// `out` starting at character position `start`; each written character occupies
// one code unit with a zero high byte. Returns the position after the last
// written character.

///|
fn write_percent_encode_to(
  out : FixedArray[Byte],
  start : Int32,
  value : String,
) -> Int32 {
  let len = value.length()
  let mut pos = start
  let mut i = 0
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code >= 0x80 {
      for byte in @utf8.encode(value[i:]) {
        let b = byte.to_int() & 0xFF
        if is_baggage_value_char(b) {
          out.unsafe_set(pos * 2, b.to_byte())
          pos = pos + 1
        } else {
          out.unsafe_set(pos * 2, b'%')
          out.unsafe_set(pos * 2 + 2, upper_hex_byte(b >> 4))
          out.unsafe_set(pos * 2 + 4, upper_hex_byte(b & 0x0F))
          pos = pos + 3
        }
      }
      return pos
    }
    if is_baggage_value_char(code) {
      out.unsafe_set(pos * 2, code.to_byte())
      pos = pos + 1
    } else {
      out.unsafe_set(pos * 2, b'%')
      out.unsafe_set(pos * 2 + 2, upper_hex_byte(code >> 4))
      out.unsafe_set(pos * 2 + 4, upper_hex_byte(code & 0x0F))
      pos = pos + 3
    }
    i = i + 1
  }
  pos
}

// Percent-encode a baggage value, leaving the characters allowed by the
// specification untouched and encoding everything else as `%XX` (UTF-8).

///|
pub fn percent_encode(value : String) -> String {
  if value == "" {
    return ""
  }
  let size = percent_encoded_length(value)
  let out : FixedArray[Byte] = FixedArray::make(size * 2, b'\x00')
  let _ = write_percent_encode_to(out, 0, value)
  out.unsafe_reinterpret_as_bytes().to_unchecked_string()
}

// Whether a code unit is HTTP optional whitespace (space, tab, CR, LF).

///|
fn is_ows_code(c : UInt16) -> Bool {
  c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D
}

// Number of bytes the percent-encoded form of `value` occupies in a `baggage`
// header. The encoded form is ASCII, so the length equals the byte count; a
// character outside the allowed set costs three bytes (`%XX`).

///|
pub fn percent_encoded_length(value : String) -> Int32 {
  let len = value.length()
  let mut total = 0
  let mut i = 0
  // ASCII text is measured from its code units; non-ASCII text on its UTF-8
  // bytes.
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code >= 0x80 {
      for byte in @utf8.encode(value[i:]) {
        if is_baggage_value_char(byte.to_int() & 0xFF) {
          total = total + 1
        } else {
          total = total + 3
        }
      }
      return total
    }
    if is_baggage_value_char(code) {
      total = total + 1
    } else {
      total = total + 3
    }
    i = i + 1
  }
  total
}

// Parse a `baggage` header value into an ordered list of key/value pairs.
// Members that are malformed are skipped; properties are ignored.
//
// Following the W3C Baggage specification, at most `BAGGAGE_MAX_MEMBERS`
// members and `BAGGAGE_MAX_BYTES` bytes are kept; once a member would exceed
// either limit it and every following member are dropped.

///|
pub fn parse_baggage(value : String) -> Array[(String, String)] {
  let entries : Array[(String, String)] = []
  // Size of the normalized header built from `entries` so far.
  let mut bytes = 0
  let view = value[:]
  let len = view.length()
  let mut start = 0
  while start <= len {
    if entries.length() >= BAGGAGE_MAX_MEMBERS {
      break
    }
    // Once the budget is exhausted no further member can fit; members that do
    // not contribute to the normalized header (malformed members, whitespace)
    // do not count towards it.
    if bytes >= BAGGAGE_MAX_BYTES {
      break
    }
    // Find the member end (the next `,`) together with the first `;` (which
    // starts the properties) and the first `=` before it.
    let mut end = start
    let mut eq = -1
    let mut semi = -1
    while end < len {
      let c = view.unsafe_get(end)
      if c == 0x2C {
        break
      }
      if c == 0x3B {
        if semi < 0 {
          semi = end
        }
      } else if c == 0x3D {
        if eq < 0 && semi < 0 {
          eq = end
        }
      }
      end = end + 1
    }
    // Trim optional whitespace around the member.
    let mut item_start = start
    while item_start < end && is_ows_code(view.unsafe_get(item_start)) {
      item_start = item_start + 1
    }
    let mut item_end = end
    while item_end > item_start && is_ows_code(view.unsafe_get(item_end - 1)) {
      item_end = item_end - 1
    }
    if item_end > item_start && eq >= 0 {
      // `eq` cannot sit in the trimmed whitespace, so it is inside the member.
      let mut key_end = eq
      while key_end > item_start && is_ows_code(view.unsafe_get(key_end - 1)) {
        key_end = key_end - 1
      }
      let key_view = view.view(start_offset=item_start, end_offset=key_end)
      if is_valid_baggage_key(key_view) {
        let value_limit = if semi >= 0 { semi } else { item_end }
        let mut value_start = eq + 1
        while value_start < value_limit &&
              is_ows_code(view.unsafe_get(value_start)) {
          value_start = value_start + 1
        }
        let mut value_end = value_limit
        while value_end > value_start &&
              is_ows_code(view.unsafe_get(value_end - 1)) {
          value_end = value_end - 1
        }
        match
          percent_decode_view_with_length(
            view.view(start_offset=value_start, end_offset=value_end),
          ) {
          Some((decoded, encoded_len)) => {
            let key = key_view.to_owned()
            let separator = if entries.length() > 0 { 1 } else { 0 }
            let size = key.length() + 1 + encoded_len + separator
            if bytes + size > BAGGAGE_MAX_BYTES {
              break
            }
            entries.push((key, decoded))
            bytes = bytes + size
          }
          None => ()
        }
      }
    }
    if end == len {
      break
    }
    start = end + 1
  }
  entries
}

// Format an ordered list of key/value pairs as a `baggage` header value.
// Pairs with an invalid key are skipped.
//
// Following the W3C Baggage specification, at most `BAGGAGE_MAX_MEMBERS`
// members and `BAGGAGE_MAX_BYTES` bytes are emitted; once a member would
// exceed either limit it and every following member are dropped.

///|
pub fn format_baggage(entries : Array[(String, String)]) -> String {
  if entries.length() == 0 {
    return ""
  }
  // First pass: size of the members that fit within the limits (at most
  // `BAGGAGE_MAX_MEMBERS` members and `BAGGAGE_MAX_BYTES` bytes). Invalid keys
  // are skipped; once a member would exceed the byte budget it and every
  // following member are dropped.
  let mut count = 0
  let mut bytes = 0
  let mut size = 0
  for entry in entries {
    if count >= BAGGAGE_MAX_MEMBERS {
      break
    }
    let (key, value) = entry
    if is_valid_baggage_key(key) {
      let separator = if count > 0 { 1 } else { 0 }
      let member_size = key.length() +
        1 +
        separator +
        percent_encoded_length(value)
      if bytes + member_size > BAGGAGE_MAX_BYTES {
        break
      }
      bytes = bytes + member_size
      size = size + member_size
      count = count + 1
    }
  }
  if count == 0 {
    return ""
  }
  // Second pass: render the selected members into a UTF-16LE buffer.
  let out : FixedArray[Byte] = FixedArray::make(size * 2, b'\x00')
  let mut pos = 0
  let mut written = 0
  for entry in entries {
    if written >= count {
      break
    }
    let (key, value) = entry
    if is_valid_baggage_key(key) {
      if written > 0 {
        out.unsafe_set(pos * 2, b',')
        pos = pos + 1
      }
      // Keys are ASCII token characters, one byte per code unit.
      let key_len = key.length()
      let mut i = 0
      while i < key_len {
        out.unsafe_set(pos * 2, key.unsafe_get(i).to_int().to_byte())
        pos = pos + 1
        i = i + 1
      }
      out.unsafe_set(pos * 2, b'=')
      pos = pos + 1
      pos = write_percent_encode_to(out, pos, value)
      written = written + 1
    }
  }
  out.unsafe_reinterpret_as_bytes().to_unchecked_string()
}

// Format the baggage of `context` as a `baggage` header value, or `None` when
// the context carries no (valid) baggage. Keys are emitted in sorted order for
// a deterministic header.
//
// The chain is walked once, collecting the innermost value of every key.

///|
pub fn context_baggage_header(context : @context.Context) -> String? {
  let mut entries : Array[(String, String)]? = None
  let mut seen : Array[String]? = None
  let mut first_key : String? = None
  let mut cursor : @context.Context? = Some(context)
  while true {
    match cursor {
      Some(node) => {
        match node.key {
          Some(key) => {
            // `insert` stays true when this is the first (innermost) occurrence
            // of `key` in the chain; later occurrences are hidden.
            let mut insert = true
            match seen {
              Some(keys) => {
                let mut i = 0
                let n = keys.length()
                while i < n {
                  if keys.unsafe_get(i) == key {
                    insert = false
                    break
                  }
                  i = i + 1
                }
                if insert {
                  keys.push(key)
                }
              }
              None =>
                match first_key {
                  Some(existing) =>
                    if existing == key {
                      insert = false
                    } else {
                      let keys : Array[String] = [existing, key]
                      seen = Some(keys)
                    }
                  None => first_key = Some(key)
                }
            }
            if insert {
              match node.value {
                Some(value) =>
                  match entries {
                    Some(list) => list.push((key, value))
                    None => entries = Some([(key, value)])
                  }
                None => ()
              }
            }
          }
          None => ()
        }
        cursor = node.parent
      }
      None => break
    }
  }
  let entries = match entries {
    Some(list) => list
    None => return None
  }
  if entries.length() > 1 {
    let n = entries.length()
    let mut i = 1
    while i < n {
      let current = entries.unsafe_get(i)
      let mut j = i
      while j > 0 && current.0.compare(entries.unsafe_get(j - 1).0) < 0 {
        entries.unsafe_set(j, entries.unsafe_get(j - 1))
        j = j - 1
      }
      entries.unsafe_set(j, current)
      i = i + 1
    }
  }
  let formatted = format_baggage(entries)
  if formatted == "" {
    None
  } else {
    Some(formatted)
  }
}

// Inject the baggage of `context` into the carrier as a `baggage` header.
// Does nothing when the context carries no baggage.

///|
pub fn inject_baggage(
  context : @context.Context,
  carrier : TextMapCarrier,
) -> Unit {
  match context_baggage_header(context) {
    Some(formatted) => carrier.set(baggage_header_name(), formatted)
    None => ()
  }
}

// Extract the baggage of a carrier as an ordered list of key/value pairs.

///|
pub fn extract_baggage(carrier : TextMapCarrier) -> Array[(String, String)] {
  match carrier.get(baggage_header_name()) {
    Some(value) => parse_baggage(value)
    None => []
  }
}

// Extract the baggage of a carrier as a Context carrying each pair.

///|
pub fn extract_baggage_context(carrier : TextMapCarrier) -> @context.Context {
  let mut context = @context.Context::root()
  for entry in extract_baggage(carrier) {
    let (key, value) = entry
    context = context.with_value(key, value)
  }
  context
}
