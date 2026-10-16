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

// Look up a single header value. HTTP header names are case-insensitive: an
// exact match is preferred, otherwise the first case-insensitive match wins.
pub fn TextMapCarrier::get(self : TextMapCarrier, key : String) -> String? {
  match self.entries.get(key) {
    Some(value) => Some(value)
    None => {
      let lowered = key.to_lower()
      let mut found : String? = None
      self.entries.each(fn(candidate, value) {
        if found is None && candidate.to_lower() == lowered {
          found = Some(value)
        }
      })
      found
    }
  }
}

// Set a single header value
pub fn TextMapCarrier::set(self : TextMapCarrier, key : String, value : String) -> Unit {
  self.entries.set(key, value)
}

// Number of headers stored in the carrier
pub fn TextMapCarrier::length(self : TextMapCarrier) -> Int {
  self.entries.length()
}

// Export the headers as a plain map
pub fn TextMapCarrier::to_map(self : TextMapCarrier) -> Map[String, String] {
  self.entries
}
