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
pub fn baggage_header_name() -> String {
  "baggage"
}

fn is_token_char(c : Char) -> Bool {
  match c {
    '!' | '#' | '$' | '%' | '&' | '\'' | '*' | '+' | '-' | '.' | '^' | '_' |
    '`' | '|' | '~' => true
    _ => (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
  }
}

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

// Whether a byte may appear literally in a baggage value. Percent-encoding is
// required for everything else (including `"`, `%`, `,`, `;` and `\`).
fn is_baggage_value_char(code : Int) -> Bool {
  (code == 0x21) ||
  (code >= 0x23 && code <= 0x2B && code != 0x25) ||
  (code >= 0x2D && code <= 0x3A) ||
  (code >= 0x3C && code <= 0x5B) ||
  (code >= 0x5D && code <= 0x7E)
}

// Upper-case ASCII code unit of every hex digit 0-9A-F.
let hex_ascii_upper : FixedArray[Char] = build_hex_ascii_upper()

fn build_hex_ascii_upper() -> FixedArray[Char] {
  let table : FixedArray[Char] = FixedArray::make(16, '0')
  let mut i = 0
  while i < 16 {
    table.unsafe_set(
      i,
      if i < 10 { (i + 48).unsafe_to_char() } else { (i + 55).unsafe_to_char() },
    )
    i = i + 1
  }
  table
}

fn upper_hex_digit(value : Int) -> Char {
  if value >= 0 && value < 16 {
    hex_ascii_upper.unsafe_get(value)
  } else {
    '0'
  }
}

// Decode the body of a baggage value that contains at least one `%`.
fn percent_decode_escaped(value : StringView) -> String? {
  let len = value.length()
  let mut decoded_len = 0
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
      if hi * 16 + lo >= 0x80 {
        ascii = false
      }
      decoded_len = decoded_len + 1
      i = i + 3
    } else {
      let code = c.to_int()
      if !is_baggage_value_char(code) {
        return None
      }
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
    Some(out.unsafe_reinterpret_as_bytes().to_unchecked_string())
  } else {
    let bytes : Array[Byte] = Array(capacity=decoded_len)
    let mut j = 0
    while j < len {
      let c = value.unsafe_get(j).unsafe_to_char()
      if c == '%' {
        let hi = hex_digit_value(value.unsafe_get(j + 1).unsafe_to_char())
        let lo = hex_digit_value(value.unsafe_get(j + 2).unsafe_to_char())
        bytes.push((hi * 16 + lo).to_byte())
        j = j + 3
      } else {
        bytes.push(c.to_int().to_byte())
        j = j + 1
      }
    }
    Some(@utf8.decode_lossy(Bytes::from_array(bytes).exact_view()))
  }
}

// Percent-decode a baggage value held as a view. Returns None when a `%`
// sequence is truncated or not followed by two hex digits.
fn percent_decode_view(value : StringView) -> String? {
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
    return Some(value.to_owned())
  }
  percent_decode_escaped(value)
}

// Percent-decode a baggage value. Returns None when a `%` sequence is
// truncated or not followed by two hex digits.
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

fn write_percent_encoded(sb : StringBuilder, code : Int) -> Unit {
  if is_baggage_value_char(code) {
    sb.write_char(code.unsafe_to_char())
  } else {
    sb.write_char('%')
    sb.write_char(upper_hex_digit(code >> 4))
    sb.write_char(upper_hex_digit(code & 0x0F))
  }
}

// Append the percent-encoded form of `value` to `sb`.
fn write_percent_encode(sb : StringBuilder, value : String) -> Unit {
  let len = value.length()
  // ASCII text is encoded from its code units, other text as UTF-8.
  let mut ascii = true
  let mut i = 0
  while i < len {
    if value.unsafe_get(i).to_int() >= 0x80 {
      ascii = false
      break
    }
    i = i + 1
  }
  if ascii {
    let mut j = 0
    while j < len {
      write_percent_encoded(sb, value.unsafe_get(j).to_int())
      j = j + 1
    }
  } else {
    for byte in @utf8.encode(value) {
      write_percent_encoded(sb, byte.to_int() & 0xFF)
    }
  }
}

// Percent-encode a baggage value, leaving the characters allowed by the
// specification untouched and encoding everything else as `%XX` (UTF-8).
pub fn percent_encode(value : String) -> String {
  let sb = StringBuilder(size_hint=value.length() * 2)
  write_percent_encode(sb, value)
  sb.to_string()
}

// Parse a `baggage` header value into an ordered list of key/value pairs.
// Members that are malformed are skipped; properties are ignored.
pub fn parse_baggage(value : String) -> Array[(String, String)] {
  let entries : Array[(String, String)] = []
  let view = value[:]
  let len = view.length()
  let mut start = 0
  while start <= len {
    let end = find_code_unit(view, ',', start)
    let item = trim_ows(view.view(start_offset=start, end_offset=end))
    if item.length() > 0 {
      // Locate the first `;` (which starts the properties) and the first `=`
      // before it in a single pass.
      let item_len = item.length()
      let mut semi = item_len
      let mut eq = -1
      let mut i = 0
      while i < item_len {
        let c = item.unsafe_get(i).unsafe_to_char()
        if c == ';' {
          semi = i
          break
        }
        if c == '=' && eq < 0 {
          eq = i
        }
        i = i + 1
      }
      if eq >= 0 {
        let key_view = trim_ows(item[:eq])
        if is_valid_baggage_key(key_view) {
          match percent_decode_view(trim_ows(item[eq + 1:semi])) {
            Some(decoded) => entries.push((key_view.to_owned(), decoded))
            None => ()
          }
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
pub fn format_baggage(entries : Array[(String, String)]) -> String {
  // Approximate output size: key, value and the `key=` separator per member.
  let mut size_hint = 0
  for entry in entries {
    let (key, value) = entry
    size_hint = size_hint + key.length() + value.length() + 2
  }
  let sb = StringBuilder(size_hint=size_hint * 2)
  let mut count = 0
  for entry in entries {
    let (key, value) = entry
    if is_valid_baggage_key(key) {
      if count > 0 {
        sb.write_char(',')
      }
      sb.write_string(key)
      sb.write_char('=')
      write_percent_encode(sb, value)
      count = count + 1
    }
  }
  sb.to_string()
}

// Format the baggage of `context` as a `baggage` header value, or `None` when
// the context carries no (valid) baggage. Keys are emitted in sorted order for
// a deterministic header.
//
// The chain is walked once, collecting the innermost value of every key.
pub fn context_baggage_header(context : @context.Context) -> String? {
  let mut entries : Array[(String, String)]? = None
  let mut seen : Map[String, Bool]? = None
  let mut first_key : String? = None
  let mut cursor : @context.Context? = Some(context)
  while true {
    match cursor {
      Some(node) => {
        match node.key {
          Some(key) =>
            match seen {
              Some(keys) =>
                if keys.get(key) is None {
                  keys.set(key, true)
                  match node.value {
                    Some(value) =>
                      match entries {
                        Some(list) => list.push((key, value))
                        None => entries = Some([(key, value)])
                      }
                    None => ()
                  }
                }
              None =>
                match first_key {
                  Some(existing) =>
                    if existing != key {
                      let keys : Map[String, Bool] = Map([])
                      keys.set(existing, true)
                      keys.set(key, true)
                      seen = Some(keys)
                      match node.value {
                        Some(value) =>
                          match entries {
                            Some(list) => list.push((key, value))
                            None => entries = Some([(key, value)])
                          }
                        None => ()
                      }
                    }
                  None => {
                    first_key = Some(key)
                    match node.value {
                      Some(value) => entries = Some([(key, value)])
                      None => ()
                    }
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
  entries.sort_by(fn(a, b) { a.0.compare(b.0) })
  let formatted = format_baggage(entries)
  if formatted == "" {
    None
  } else {
    Some(formatted)
  }
}

// Inject the baggage of `context` into the carrier as a `baggage` header.
// Does nothing when the context carries no baggage.
pub fn inject_baggage(context : @context.Context, carrier : TextMapCarrier) -> Unit {
  match context_baggage_header(context) {
    Some(formatted) => carrier.set(baggage_header_name(), formatted)
    None => ()
  }
}

// Extract the baggage of a carrier as an ordered list of key/value pairs.
pub fn extract_baggage(carrier : TextMapCarrier) -> Array[(String, String)] {
  match carrier.get(baggage_header_name()) {
    Some(value) => parse_baggage(value)
    None => []
  }
}

// Extract the baggage of a carrier as a Context carrying each pair.
pub fn extract_baggage_context(carrier : TextMapCarrier) -> @context.Context {
  let mut context = @context.Context::root()
  for entry in extract_baggage(carrier) {
    let (key, value) = entry
    context = context.with_value(key, value)
  }
  context
}
