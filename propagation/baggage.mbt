// W3C Baggage propagator for the `baggage` header.
//
// `baggage` layout: a comma-separated list of `key=value` members, where each
// member may carry `;`-separated properties. Keys are HTTP tokens; values are
// percent-encoded so that any octet can be represented. Parsing is lenient:
// members with a malformed key, value or encoding are dropped, malformed
// properties are skipped, while the remaining members are kept.
//
// `parse_baggage` / `format_baggage` work with plain key/value pairs and drop
// properties. `parse_baggage_entries` / `format_baggage_entries` surface the
// properties as `BaggageEntry` values, so a full member
// (`key=value;prop=1`) round-trips.

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

// One member of a `baggage` header: a key, a percent-decoded value and the
// (percent-decoded) properties attached to the member. Constructed by
// `parse_baggage_entries` / `BaggageEntry::new` and accepted by
// `format_baggage_entries`.

///|
pub(all) struct BaggageEntry {
  key : String
  value : String
  properties : Array[(String, String)]
} derive(Eq, @debug.Debug)

// Create a baggage member with optional `key=value` properties. The
// properties array is stored as given; callers must not mutate it afterwards.

///|
pub fn BaggageEntry::new(
  key : String,
  value : String,
  properties? : Array[(String, String)],
) -> BaggageEntry {
  {
    key,
    value,
    properties: match properties {
      Some(values) => values
      None => []
    },
  }
}

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

// Sentinel encoded length returned for invalid baggage values. A real encoded
// length is never negative (the empty value has length 0).
const INVALID_BAGGAGE_LENGTH : Int32 = -1

// Decode the body of a baggage value that contains at least one `%`.
// Returns the decoded string together with the byte length of its
// percent-encoded form, or `("", INVALID_BAGGAGE_LENGTH)` when the value is
// malformed. In the non-ASCII case (where lossy UTF-8 decoding makes the byte
// accounting hard to track) the length is recomputed from the decoded string
// to stay exactly equivalent to `percent_encoded_length`.

///|
fn percent_decode_escaped_with_length(value : StringView) -> (String, Int32) {
  let len = value.length()
  let mut decoded_len = 0
  let mut encoded_len = 0
  let mut ascii = true
  let mut i = 0
  while i < len {
    let c = value.unsafe_get(i).unsafe_to_char()
    if c == '%' {
      if i + 2 >= len {
        return ("", INVALID_BAGGAGE_LENGTH)
      }
      let hi = hex_digit_value(value.unsafe_get(i + 1).unsafe_to_char())
      let lo = hex_digit_value(value.unsafe_get(i + 2).unsafe_to_char())
      if hi < 0 || lo < 0 {
        return ("", INVALID_BAGGAGE_LENGTH)
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
        return ("", INVALID_BAGGAGE_LENGTH)
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
    (out.unsafe_reinterpret_as_bytes().to_unchecked_string(), encoded_len)
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
    (decoded, percent_encoded_length(decoded))
  }
}

// Decode the body of a baggage value that contains at least one `%`.

///|
fn percent_decode_escaped(value : StringView) -> String? {
  let (decoded, encoded_len) = percent_decode_escaped_with_length(value)
  if encoded_len < 0 {
    None
  } else {
    Some(decoded)
  }
}

// Percent-decode a baggage value held as a view, also reporting the byte
// length of its percent-encoded form. Returns `("", INVALID_BAGGAGE_LENGTH)`
// when a `%` sequence is truncated or not followed by two hex digits, or when
// a character may not appear literally in a value.

///|
fn percent_decode_view_with_length(value : StringView) -> (String, Int32) {
  let len = value.length()
  // A value without `%` decodes to itself; its characters still need
  // validating. Every kept character is allowed literally, so the encoded
  // length equals the number of characters.
  let mut i = 0
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code == 0x25 {
      return percent_decode_escaped_with_length(value)
    }
    if !is_baggage_value_char(code) {
      return ("", INVALID_BAGGAGE_LENGTH)
    }
    i = i + 1
  }
  (value.to_owned(), len)
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
      // Allowed characters come in runs; two of them are written per 32-bit
      // store. The high byte of every code unit stays zero because the buffer
      // is zero-initialized.
      let mut end = i + 1
      while end < len && is_baggage_value_char(value.unsafe_get(end).to_int()) {
        end = end + 1
      }
      while i + 1 < end {
        let c0 = value.unsafe_get(i).to_int()
        let c1 = value.unsafe_get(i + 1).to_int()
        out.unsafe_write_uint32_le(
          pos * 2,
          (c0 | (c1 << 16)).reinterpret_as_uint(),
        )
        pos = pos + 2
        i = i + 2
      }
      if i < end {
        out.unsafe_set(pos * 2, value.unsafe_get(i).to_int().to_byte())
        pos = pos + 1
        i = i + 1
      }
    } else {
      out.unsafe_set(pos * 2, b'%')
      out.unsafe_set(pos * 2 + 2, upper_hex_byte(code >> 4))
      out.unsafe_set(pos * 2 + 4, upper_hex_byte(code & 0x0F))
      pos = pos + 3
      i = i + 1
    }
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

// Parse the `;`-separated properties of a member spanning `[semi, item_end)`
// (`semi` points at the first `;`, or is -1 when the member has none).
// Malformed properties and duplicates of an already accepted property key are
// skipped; the property values are percent-decoded like member values.

///|
fn parse_baggage_properties(
  view : StringView,
  semi : Int32,
  item_end : Int32,
) -> Array[(String, String)] {
  let properties : Array[(String, String)] = []
  if semi < 0 {
    return properties
  }
  let mut start = semi
  while start < item_end {
    let mut end = start + 1
    while end < item_end && view.unsafe_get(end) != 0x3B {
      end = end + 1
    }
    let mut item_start = start + 1
    while item_start < end && is_ows_code(view.unsafe_get(item_start)) {
      item_start = item_start + 1
    }
    let mut property_end = end
    while property_end > item_start &&
          is_ows_code(view.unsafe_get(property_end - 1)) {
      property_end = property_end - 1
    }
    let mut eq = -1
    let mut i = item_start
    while i < property_end {
      if view.unsafe_get(i) == 0x3D {
        eq = i
        break
      }
      i = i + 1
    }
    if eq >= 0 {
      let mut key_end = eq
      while key_end > item_start && is_ows_code(view.unsafe_get(key_end - 1)) {
        key_end = key_end - 1
      }
      let key_view = view.view(start_offset=item_start, end_offset=key_end)
      let mut value_start = eq + 1
      while value_start < property_end &&
            is_ows_code(view.unsafe_get(value_start)) {
        value_start = value_start + 1
      }
      let mut value_end = property_end
      while value_end > value_start &&
            is_ows_code(view.unsafe_get(value_end - 1)) {
        value_end = value_end - 1
      }
      if is_valid_baggage_key(key_view) {
        let (decoded, encoded_len) = percent_decode_view_with_length(
          view.view(start_offset=value_start, end_offset=value_end),
        )
        if encoded_len >= 0 {
          let key = key_view.to_owned()
          let mut duplicate = false
          for existing in properties {
            if existing.0 == key {
              duplicate = true
              break
            }
          }
          if !duplicate {
            properties.push((key, decoded))
          }
        }
      }
    }
    start = end
  }
  properties
}

// Parse a `baggage` header value into an ordered list of members, keeping the
// properties of each member.
//
// Members that are malformed are skipped; malformed properties are skipped
// while the member itself is kept. Following the W3C Baggage specification, at
// most `BAGGAGE_MAX_MEMBERS` members and `BAGGAGE_MAX_BYTES` bytes (properties
// included) are kept; once a member would exceed either limit it and every
// following member are dropped.

///|
pub fn parse_baggage_entries(value : String) -> Array[BaggageEntry] {
  let entries : Array[BaggageEntry] = []
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
        let (decoded, encoded_len) = percent_decode_view_with_length(
          view.view(start_offset=value_start, end_offset=value_end),
        )
        if encoded_len >= 0 {
          let properties = parse_baggage_properties(view, semi, item_end)
          let key = key_view.to_owned()
          let separator = if entries.length() > 0 { 1 } else { 0 }
          let mut size = key.length() + 1 + encoded_len + separator
          for property in properties {
            size = size + baggage_property_size(property.0, property.1)
          }
          if bytes + size > BAGGAGE_MAX_BYTES {
            break
          }
          entries.push({ key, value: decoded, properties, })
          bytes = bytes + size
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

// Parse a `baggage` header value into an ordered list of key/value pairs.
// Members that are malformed are skipped; properties are dropped (use
// `parse_baggage_entries` to keep them).
//
// Following the W3C Baggage specification, at most `BAGGAGE_MAX_MEMBERS`
// members and `BAGGAGE_MAX_BYTES` bytes are kept; once a member would exceed
// either limit it and every following member are dropped.

///|
pub fn parse_baggage(value : String) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  // Size of the normalized header built from `pairs` so far.
  let mut bytes = 0
  let view = value[:]
  let len = view.length()
  let mut start = 0
  while start <= len {
    if pairs.length() >= BAGGAGE_MAX_MEMBERS {
      break
    }
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
        let (decoded, encoded_len) = percent_decode_view_with_length(
          view.view(start_offset=value_start, end_offset=value_end),
        )
        if encoded_len >= 0 {
          // Properties are dropped, so they do not contribute to the size.
          let key = key_view.to_owned()
          let separator = if pairs.length() > 0 { 1 } else { 0 }
          let size = key.length() + 1 + encoded_len + separator
          if bytes + size > BAGGAGE_MAX_BYTES {
            break
          }
          pairs.push((key, decoded))
          bytes = bytes + size
        }
      }
    }
    if end == len {
      break
    }
    start = end + 1
  }
  pairs
}

// Number of bytes the `;key=value` form of one property occupies in a
// normalized `baggage` header.

///|
fn baggage_property_size(key : String, value : String) -> Int32 {
  1 + key.length() + 1 + percent_encoded_length(value)
}

// Write a validated baggage key (ASCII token characters, one byte per code
// unit; two of them are written per 32-bit store) into the UTF-16LE buffer and
// return the position after the key.

///|
fn write_baggage_key_to(
  out : FixedArray[Byte],
  pos : Int32,
  key : String,
) -> Int32 {
  let key_len = key.length()
  let mut pos = pos
  let mut i = 0
  while i + 1 < key_len {
    let c0 = key.unsafe_get(i).to_int()
    let c1 = key.unsafe_get(i + 1).to_int()
    out.unsafe_write_uint32_le(pos * 2, (c0 | (c1 << 16)).reinterpret_as_uint())
    pos = pos + 2
    i = i + 2
  }
  if i < key_len {
    out.unsafe_set(pos * 2, key.unsafe_get(i).to_int().to_byte())
    pos = pos + 1
  }
  pos
}

// Format an ordered list of baggage members as a `baggage` header value.
// Members with an invalid key are skipped; properties with an invalid or
// duplicate key are skipped while their member is kept.
//
// Following the W3C Baggage specification, at most `BAGGAGE_MAX_MEMBERS`
// members and `BAGGAGE_MAX_BYTES` bytes (properties included) are emitted;
// once a member would exceed either limit it and every following member are
// dropped.

///|
pub fn format_baggage_entries(entries : Array[BaggageEntry]) -> String {
  if entries.length() == 0 {
    return ""
  }
  let mut size = 0
  // Fast path: every member is valid, has no properties and fits within the
  // limits, so the input array can be rendered without building a normalized
  // copy first.
  let mut simple = entries.length() <= BAGGAGE_MAX_MEMBERS
  if simple {
    let mut bytes = 0
    let mut i = 0
    while i < entries.length() {
      let entry = entries.unsafe_get(i)
      if !is_valid_baggage_key(entry.key) || entry.properties.length() > 0 {
        simple = false
        break
      }
      let separator = if i > 0 { 1 } else { 0 }
      let member_size = entry.key.length() +
        1 +
        separator +
        percent_encoded_length(entry.value)
      if bytes + member_size > BAGGAGE_MAX_BYTES {
        simple = false
        break
      }
      bytes = bytes + member_size
      i = i + 1
    }
    if simple {
      size = bytes
    }
  }
  let members : Array[BaggageEntry] = if simple {
    entries
  } else {
    // Normalize the members that fit within the limits (at most
    // `BAGGAGE_MAX_MEMBERS` members and `BAGGAGE_MAX_BYTES` bytes). Invalid
    // keys are skipped, invalid or duplicated properties are dropped; once a
    // member would exceed the byte budget it and every following member are
    // dropped.
    let members : Array[BaggageEntry] = Array(capacity=entries.length())
    let mut bytes = 0
    for entry in entries {
      if members.length() >= BAGGAGE_MAX_MEMBERS {
        break
      }
      if !is_valid_baggage_key(entry.key) {
        continue
      }
      let properties : Array[(String, String)] = []
      for property in entry.properties {
        if is_valid_baggage_key(property.0) {
          let mut duplicate = false
          for existing in properties {
            if existing.0 == property.0 {
              duplicate = true
              break
            }
          }
          if !duplicate {
            properties.push(property)
          }
        }
      }
      let separator = if members.length() > 0 { 1 } else { 0 }
      let mut member_size = entry.key.length() +
        1 +
        separator +
        percent_encoded_length(entry.value)
      for property in properties {
        member_size = member_size + baggage_property_size(property.0, property.1)
      }
      if bytes + member_size > BAGGAGE_MAX_BYTES {
        break
      }
      members.push({ key: entry.key, value: entry.value, properties, })
      bytes = bytes + member_size
      size = size + member_size
    }
    members
  }
  if members.length() == 0 {
    return ""
  }
  // Render the selected members into a UTF-16LE buffer.
  let out : FixedArray[Byte] = FixedArray::make(size * 2, b'\x00')
  let mut pos = 0
  let mut written = 0
  for entry in members {
    if written > 0 {
      out.unsafe_set(pos * 2, b',')
      pos = pos + 1
    }
    pos = write_baggage_key_to(out, pos, entry.key)
    out.unsafe_set(pos * 2, b'=')
    pos = pos + 1
    pos = write_percent_encode_to(out, pos, entry.value)
    for property in entry.properties {
      out.unsafe_set(pos * 2, b';')
      pos = pos + 1
      pos = write_baggage_key_to(out, pos, property.0)
      out.unsafe_set(pos * 2, b'=')
      pos = pos + 1
      pos = write_percent_encode_to(out, pos, property.1)
    }
    written = written + 1
  }
  out.unsafe_reinterpret_as_bytes().to_unchecked_string()
}

// Format an ordered list of key/value pairs as a `baggage` header value.
// Pairs with an invalid key are skipped; no properties are emitted.
//
// Following the W3C Baggage specification, at most `BAGGAGE_MAX_MEMBERS`
// members and `BAGGAGE_MAX_BYTES` bytes are emitted; once a member would
// exceed either limit it and every following member are dropped.

///|
pub fn format_baggage(entries : Array[(String, String)]) -> String {
  if entries.length() == 0 {
    return ""
  }
  let mut size = 0
  // Fast path: every pair is valid and fits within the limits, so the input
  // can be rendered without building a selected copy.
  let mut simple = entries.length() <= BAGGAGE_MAX_MEMBERS
  if simple {
    let mut bytes = 0
    let mut i = 0
    while i < entries.length() {
      let entry = entries.unsafe_get(i)
      if !is_valid_baggage_key(entry.0) {
        simple = false
        break
      }
      let separator = if i > 0 { 1 } else { 0 }
      let member_size = entry.0.length() +
        1 +
        separator +
        percent_encoded_length(entry.1)
      if bytes + member_size > BAGGAGE_MAX_BYTES {
        simple = false
        break
      }
      bytes = bytes + member_size
      i = i + 1
    }
    if simple {
      size = bytes
    }
  }
  let selected : Array[(String, String)] = if simple {
    entries
  } else {
    // Select the members that fit within the limits. Invalid keys are
    // skipped; once a member would exceed the byte budget it and every
    // following member are dropped.
    let selected : Array[(String, String)] = Array(capacity=entries.length())
    let mut bytes = 0
    for entry in entries {
      if selected.length() >= BAGGAGE_MAX_MEMBERS {
        break
      }
      let key = entry.0
      if !is_valid_baggage_key(key) {
        continue
      }
      let separator = if selected.length() > 0 { 1 } else { 0 }
      let member_size = key.length() +
        1 +
        separator +
        percent_encoded_length(entry.1)
      if bytes + member_size > BAGGAGE_MAX_BYTES {
        break
      }
      selected.push(entry)
      bytes = bytes + member_size
      size = size + member_size
    }
    selected
  }
  if selected.length() == 0 {
    return ""
  }
  // Render the selected members into a UTF-16LE buffer.
  let out : FixedArray[Byte] = FixedArray::make(size * 2, b'\x00')
  let mut pos = 0
  let mut written = 0
  for entry in selected {
    if written > 0 {
      out.unsafe_set(pos * 2, b',')
      pos = pos + 1
    }
    pos = write_baggage_key_to(out, pos, entry.0)
    out.unsafe_set(pos * 2, b'=')
    pos = pos + 1
    pos = write_percent_encode_to(out, pos, entry.1)
    written = written + 1
  }
  out.unsafe_reinterpret_as_bytes().to_unchecked_string()
}

// Format the baggage of `context` as a `baggage` header value, or `None` when
// the context carries no (valid) baggage. Keys are emitted in sorted order for
// a deterministic header. Baggage properties stored in the context are
// preserved.

///|
pub fn context_baggage_header(context : @context.Context) -> String? {
  let baggage = context.baggage_entries()
  if baggage.length() == 0 {
    return None
  }
  let entries : Array[BaggageEntry] = []
  for entry in baggage {
    entries.push(
      BaggageEntry::new(entry.key, entry.value, properties=entry.properties),
    )
  }
  // Small lists are sorted with an insertion sort; larger lists use the
  // generic sort.
  let entry_count = entries.length()
  if entry_count > 16 {
    entries.sort_by(fn(a, b) { a.key.compare(b.key) })
  } else if entry_count > 1 {
    let mut i = 1
    while i < entry_count {
      let current = entries.unsafe_get(i)
      let mut j = i
      while j > 0 && current.key.compare(entries.unsafe_get(j - 1).key) < 0 {
        entries.unsafe_set(j, entries.unsafe_get(j - 1))
        j = j - 1
      }
      entries.unsafe_set(j, current)
      i = i + 1
    }
  }
  let formatted = format_baggage_entries(entries)
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
// Properties are dropped; use `extract_baggage_entries` to keep them.

///|
pub fn extract_baggage(carrier : TextMapCarrier) -> Array[(String, String)] {
  match carrier.get(baggage_header_name()) {
    Some(value) => parse_baggage(value)
    None => []
  }
}

// Extract the baggage of a carrier as an ordered list of members, keeping the
// properties of each member.

///|
pub fn extract_baggage_entries(
  carrier : TextMapCarrier,
) -> Array[BaggageEntry] {
  match carrier.get(baggage_header_name()) {
    Some(value) => parse_baggage_entries(value)
    None => []
  }
}

// Inject an ordered list of baggage members into the carrier as a `baggage`
// header. Does nothing when no member survives formatting.

///|
pub fn inject_baggage_entries(
  entries : Array[BaggageEntry],
  carrier : TextMapCarrier,
) -> Unit {
  let formatted = format_baggage_entries(entries)
  if formatted != "" {
    carrier.set(baggage_header_name(), formatted)
  }
}

// Extract the baggage of a carrier as a Context carrying each member,
// including its W3C baggage properties.

///|
pub fn extract_baggage_context(carrier : TextMapCarrier) -> @context.Context {
  let entries = extract_baggage_entries(carrier)
  if entries.length() == 0 {
    return @context.Context::root()
  }
  let context_entries : Array[@context.BaggageEntry] = []
  for entry in entries {
    context_entries.push(
      @context.BaggageEntry::new(
        entry.key,
        entry.value,
        properties=entry.properties,
      ),
    )
  }
  @context.Context::root().with_baggage_entries(context_entries)
}

///|
pub extend BaggageEntry with Eq::{not_equal, equal}

///|
pub extend BaggageEntry with @debug.Debug::{to_repr}
