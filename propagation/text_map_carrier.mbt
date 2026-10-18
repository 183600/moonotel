// TextMapCarrier is a simple in-memory carrier for text-based propagation
// formats such as W3C Trace Context. Header names are stored verbatim.
pub struct TextMapCarrier {
  entries : Map[String, String]
}

// Create an empty carrier
pub fn TextMapCarrier::new() -> TextMapCarrier {
  { entries: Map([]) }
}

// Create a carrier backed by an existing map (values are shared, not copied)
pub fn TextMapCarrier::from_map(entries : Map[String, String]) -> TextMapCarrier {
  { entries, }
}

// Create a carrier from an array of key/value pairs
pub fn TextMapCarrier::from_entries(entries : Array[(String, String)]) -> TextMapCarrier {
  { entries: Map(entries), }
}

// ASCII-case-insensitive equality. Equivalent to `a.to_lower() == b.to_lower()`
// because `to_lower` only maps `A`-`Z`.
fn ascii_case_insensitive_equal(a : String, b : String) -> Bool {
  let len = a.length()
  if len != b.length() {
    return false
  }
  let mut i = 0
  while i < len {
    let ca = a.unsafe_get(i).to_int()
    let cb = b.unsafe_get(i).to_int()
    if ca != cb {
      let na = if ca >= 65 && ca <= 90 { ca + 32 } else { ca }
      let nb = if cb >= 65 && cb <= 90 { cb + 32 } else { cb }
      if na != nb {
        return false
      }
    }
    i = i + 1
  }
  true
}

// Look up a single header value. HTTP header names are case-insensitive: an
// exact match is preferred, otherwise the first case-insensitive match wins.
pub fn TextMapCarrier::get(self : TextMapCarrier, key : String) -> String? {
  match self.entries.get(key) {
    Some(value) => Some(value)
    None => {
      for candidate, value in self.entries {
        if ascii_case_insensitive_equal(candidate, key) {
          return Some(value)
        }
      }
      None
    }
  }
}

// Set a single header value
pub fn TextMapCarrier::set(self : TextMapCarrier, key : String, value : String) -> Unit {
  self.entries.set(key, value)
}

// Remove a single header value. Like `get`, the lookup is case-insensitive.
pub fn TextMapCarrier::remove(self : TextMapCarrier, key : String) -> Unit {
  self.entries.remove(key)
  let matches : Array[String] = []
  for candidate, _value in self.entries {
    if ascii_case_insensitive_equal(candidate, key) {
      matches.push(candidate)
    }
  }
  for candidate in matches {
    self.entries.remove(candidate)
  }
}

// Number of headers stored in the carrier
pub fn TextMapCarrier::length(self : TextMapCarrier) -> Int {
  self.entries.length()
}

// Export the headers as a plain map
pub fn TextMapCarrier::to_map(self : TextMapCarrier) -> Map[String, String] {
  self.entries
}
