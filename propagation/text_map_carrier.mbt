// TextMapCarrier is a simple in-memory carrier for text-based propagation
// formats such as W3C Trace Context. Header names are stored verbatim.
//
// A carrier can also view external storage through the callbacks installed by
// `from_getter`, `from_setter` and `from_getter_setter`. Instrumentations use
// this to propagate through an existing header map without copying it: reads
// fall back to the getter and writes are forwarded to the setter. Without an
// external setter, `set` stores values in the carrier itself; `length`,
// `to_map` and `remove` always operate on the carrier's own entries only.

///|
pub struct TextMapCarrier {
  entries : Map[String, String]
  // External read view, consulted when a key is not stored locally.
  getter : ((String) -> String?)?
  // External write target. When present, `set` forwards to it.
  setter : ((String, String) -> Unit)?
}

// Create an empty carrier

///|
pub fn TextMapCarrier::new() -> TextMapCarrier {
  { entries: Map([]), getter: None, setter: None, }
}

// Create a carrier backed by an existing map (values are shared, not copied)

///|
pub fn TextMapCarrier::from_map(
  entries : Map[String, String],
) -> TextMapCarrier {
  { entries, getter: None, setter: None, }
}

// Create a carrier from an array of key/value pairs

///|
pub fn TextMapCarrier::from_entries(
  entries : Array[(String, String)],
) -> TextMapCarrier {
  { entries: Map(entries), getter: None, setter: None, }
}

// Create a read-only carrier that looks up keys through `get` when they are
// not stored locally. The keys are passed to `get` unchanged, so an external
// store with its own case rules (for example HTTP headers) keeps them.

///|
pub fn TextMapCarrier::from_getter(
  get : (String) -> String?,
) -> TextMapCarrier {
  { entries: Map([]), getter: Some(get), setter: None, }
}

// Create a write-through carrier: `set` forwards every write to `set`.
// Reads only see values stored locally.

///|
pub fn TextMapCarrier::from_setter(
  set : (String, String) -> Unit,
) -> TextMapCarrier {
  { entries: Map([]), getter: None, setter: Some(set), }
}

// Create a carrier that both reads through `get` and writes through `set`.

///|
pub fn TextMapCarrier::from_getter_setter(
  get : (String) -> String?,
  set : (String, String) -> Unit,
) -> TextMapCarrier {
  { entries: Map([]), getter: Some(get), setter: Some(set), }
}

// ASCII-case-insensitive equality. Equivalent to `a.to_lower() == b.to_lower()`
// because `to_lower` only maps `A`-`Z`.

///|
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

///|
pub fn TextMapCarrier::get(self : TextMapCarrier, key : String) -> String? {
  match self.entries.get(key) {
    Some(value) => Some(value)
    None => {
      for candidate, value in self.entries.iter2() {
        if ascii_case_insensitive_equal(candidate, key) {
          return Some(value)
        }
      }
      match self.getter {
        Some(get) => get(key)
        None => None
      }
    }
  }
}

// Set a single header value. Write-through carriers forward the value to their
// external store instead of keeping it locally.

///|
pub fn TextMapCarrier::set(
  self : TextMapCarrier,
  key : String,
  value : String,
) -> Unit {
  match self.setter {
    Some(set) => set(key, value)
    None => self.entries.set(key, value)
  }
}

// Remove a single header value. Like `get`, the lookup is case-insensitive.

///|
pub fn TextMapCarrier::remove(self : TextMapCarrier, key : String) -> Unit {
  self.entries.remove(key)
  let matches : Array[String] = []
  for candidate, _value in self.entries.iter2() {
    if ascii_case_insensitive_equal(candidate, key) {
      matches.push(candidate)
    }
  }
  for candidate in matches {
    self.entries.remove(candidate)
  }
}

// Number of headers stored in the carrier

///|
pub fn TextMapCarrier::length(self : TextMapCarrier) -> Int32 {
  self.entries.length()
}

// Export the headers as a plain map

///|
pub fn TextMapCarrier::to_map(self : TextMapCarrier) -> Map[String, String] {
  self.entries
}
