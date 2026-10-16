// TextMapCarrier is a simple in-memory carrier for text-based propagation
// formats such as W3C Trace Context. Header names are stored verbatim.
pub struct TextMapCarrier {
  entries : Map[String, String]
}

// Create an empty carrier
pub fn TextMapCarrier::new() -> TextMapCarrier {
  { entries: Map::new() }
}

// Create a carrier backed by an existing map (values are shared, not copied)
pub fn TextMapCarrier::from_map(entries : Map[String, String]) -> TextMapCarrier {
  { entries, }
}

// Create a carrier from an array of key/value pairs
pub fn TextMapCarrier::from_entries(entries : Array[(String, String)]) -> TextMapCarrier {
  let map = Map::new()
  for entry in entries {
    map.set(entry.0, entry.1)
  }
  { entries: map, }
}

// Look up a single header value
pub fn TextMapCarrier::get(self : TextMapCarrier, key : String) -> String? {
  self.entries.get(key)
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
