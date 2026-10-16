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

fn is_valid_baggage_key(key : String) -> Bool {
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
// required for everything else (including `"`, `,`, `;` and `\`).
fn is_baggage_value_char(code : Int) -> Bool {
  (code >= 0x21 && code <= 0x2B) ||
  (code >= 0x2D && code <= 0x3A) ||
  (code >= 0x3C && code <= 0x5B) ||
  (code >= 0x5D && code <= 0x7E)
}

fn upper_hex_digit(value : Int) -> Char {
  if value >= 0 && value < 10 {
    (value + 48).unsafe_to_char()
  } else if value >= 10 && value < 16 {
    (value + 55).unsafe_to_char()
  } else {
    '0'
  }
}

// Percent-decode a baggage value. Returns None when a `%` sequence is
// truncated or not followed by two hex digits.
pub fn percent_decode(value : String) -> String? {
  let len = value.length()
  let bytes : Array[Byte] = Array(capacity=len)
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
      bytes.push((hi * 16 + lo).to_byte())
      i = i + 3
    } else {
      let code = c.to_int()
      if !is_baggage_value_char(code) {
        return None
      }
      bytes.push(code.to_byte())
      i = i + 1
    }
  }
  Some(@utf8.decode_lossy(Bytes::from_array(bytes).exact_view()))
}

// Percent-encode a baggage value, leaving the characters allowed by the
// specification untouched and encoding everything else as `%XX` (UTF-8).
pub fn percent_encode(value : String) -> String {
  let sb = StringBuilder(size_hint=value.length())
  for byte in @utf8.encode(value) {
    let code = byte.to_int() & 0xFF
    if is_baggage_value_char(code) {
      sb.write_char(code.unsafe_to_char())
    } else {
      sb.write_char('%')
      sb.write_char(upper_hex_digit(code >> 4))
      sb.write_char(upper_hex_digit(code & 0x0F))
    }
  }
  sb.to_string()
}

// Parse a `baggage` header value into an ordered list of key/value pairs.
// Members that are malformed are skipped; properties are ignored.
pub fn parse_baggage(value : String) -> Array[(String, String)] {
  let entries : Array[(String, String)] = []
  for raw in value.split(",") {
    let item = raw.trim()
    if item == "" {
      continue
    }
    let pair_text = match item.find(";") {
      Some(index) => item[:index]
      None => item
    }
    let (key_view, value_view) = match pair_text.split_once("=") {
      Some(pair) => pair
      None => continue
    }
    let key = key_view.trim().to_owned()
    if !is_valid_baggage_key(key) {
      continue
    }
    match percent_decode(value_view.trim().to_owned()) {
      Some(decoded) => entries.push((key, decoded))
      None => continue
    }
  }
  entries
}

// Format an ordered list of key/value pairs as a `baggage` header value.
// Pairs with an invalid key are skipped.
pub fn format_baggage(entries : Array[(String, String)]) -> String {
  let parts : Array[String] = []
  for entry in entries {
    let (key, value) = entry
    if is_valid_baggage_key(key) {
      parts.push(key + "=" + percent_encode(value))
    }
  }
  parts.join(",")
}

// Format the baggage of `context` as a `baggage` header value, or `None` when
// the context carries no (valid) baggage. Keys are emitted in sorted order for
// a deterministic header.
pub fn context_baggage_header(context : @context.Context) -> String? {
  let baggage = context.baggage()
  if baggage.length() == 0 {
    return None
  }
  let keys : Array[String] = []
  baggage.each(fn(key, _value) { keys.push(key) })
  keys.sort()
  let entries : Array[(String, String)] = []
  for key in keys {
    match baggage.get(key) {
      Some(value) => entries.push((key, value))
      None => ()
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
