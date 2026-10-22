// TextMapCarrier is a simple in-memory carrier for text-based propagation
// formats such as W3C Trace Context. Header names are stored verbatim.
//
// A carrier can also view external storage through the callbacks installed by
// `from_getter`, `from_setter` and `from_getter_setter`. Instrumentations use
// this to propagate through an existing header map without copying it: reads
// fall back to the getter, writes are forwarded to the setter and (when an
// external `remove` callback is supplied) deletions are forwarded as well.
// Without an external setter, `set` stores values in the carrier itself;
// `length` and `to_map` always operate on the carrier's own entries only.

///|
pub struct TextMapCarrier {
  entries : Map[String, String]
  // External read view, consulted when a key is not stored locally.
  getter : ((String) -> String?)?
  // External write target. When present, `set` forwards to it.
  setter : ((String, String) -> Unit)?
  // External delete target. When present, `remove` forwards to it so that a
  // propagator can clear headers stored outside the carrier (for example an
  // HTTP request's header map).
  remover : ((String) -> Unit)?
}

// Create an empty carrier

///|
pub fn TextMapCarrier::new() -> TextMapCarrier {
  { entries: Map([]), getter: None, setter: None, remover: None, }
}

// Create a carrier backed by an existing map (values are shared, not copied)

///|
pub fn TextMapCarrier::from_map(
  entries : Map[String, String],
) -> TextMapCarrier {
  { entries, getter: None, setter: None, remover: None, }
}

// Create a carrier from an array of key/value pairs. A repeated key is
// combined into one comma-separated value, as required for HTTP headers by
// RFC 7230 section 3.2.2.

///|
pub fn TextMapCarrier::from_entries(
  entries : Array[(String, String)],
) -> TextMapCarrier {
  let map : Map[String, String] = Map([])
  for entry in entries {
    match map.get(entry.0) {
      Some(existing) => map.set(entry.0, existing + ", " + entry.1)
      None => {
        let mut matched : (String, String)? = None
        for candidate, existing in map {
          if ascii_case_insensitive_equal(candidate, entry.0) {
            matched = Some((candidate, existing))
            break
          }
        }
        match matched {
          Some((candidate, existing)) =>
            map.set(candidate, existing + ", " + entry.1)
          None => map.set(entry.0, entry.1)
        }
      }
    }
  }
  { entries: map, getter: None, setter: None, remover: None, }
}

// Create a read-only carrier that looks up keys through `get` when they are
// not stored locally. The keys are passed to `get` unchanged, so an external
// store with its own case rules (for example HTTP headers) keeps them.

///|
pub fn TextMapCarrier::from_getter(
  get : (String) -> String?,
) -> TextMapCarrier {
  { entries: Map([]), getter: Some(get), setter: None, remover: None, }
}

// Create a write-through carrier: `set` forwards every write to `set`.
// Reads only see values stored locally.

///|
pub fn TextMapCarrier::from_setter(
  set : (String, String) -> Unit,
) -> TextMapCarrier {
  { entries: Map([]), getter: None, setter: Some(set), remover: None, }
}

// Create a carrier that both reads through `get` and writes through `set`.
// When `remove` is supplied it is called by `remove`, so propagators can also
// delete headers stored outside the carrier.

///|
pub fn TextMapCarrier::from_getter_setter(
  get : (String) -> String?,
  set : (String, String) -> Unit,
  remove? : (String) -> Unit,
) -> TextMapCarrier {
  {
    entries: Map([]),
    getter: Some(get),
    setter: Some(set),
    remover: remove,
  }
}

// Smallest power-of-two map capacity that holds `entries` entries without a
// rehash, accounting for the map's 13/16 grow threshold.

///|
fn map_capacity_for_entries(entries : Int) -> Int {
  let capacity = entries.next_power_of_two()
  if entries > capacity * 13 / 16 {
    capacity * 2
  } else {
    capacity
  }
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
      if self.entries.length() > 0 {
        for candidate, value in self.entries {
          if ascii_case_insensitive_equal(candidate, key) {
            return Some(value)
          }
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

// Remove a single header value. Like `get`, the local lookup is
// case-insensitive. A carrier created with an external `remove` callback also
// forwards the deletion to that store, so `inject` can clear stale headers.

///|
pub fn TextMapCarrier::remove(self : TextMapCarrier, key : String) -> Unit {
  self.entries.remove(key)
  // Collect the keys that match `key` case-insensitively, then remove them.
  let mut matches : Array[String]? = None
  if self.entries.length() > 0 {
    for candidate, _value in self.entries {
      if ascii_case_insensitive_equal(candidate, key) {
        match matches {
          Some(list) => list.push(candidate)
          None => matches = Some([candidate])
        }
      }
    }
  }
  match matches {
    Some(list) =>
      for candidate in list {
        self.entries.remove(candidate)
      }
    None => ()
  }
  match self.remover {
    Some(remove) => remove(key)
    None => ()
  }
}

// Number of headers stored in the carrier

///|
pub fn TextMapCarrier::length(self : TextMapCarrier) -> Int32 {
  self.entries.length()
}

// Export the headers as a plain map. The returned map is a shallow copy, so
// modifying it does not change the carrier; for a write-through carrier it
// only holds the entries stored locally (external headers read through the
// getter are not included).

///|
pub fn TextMapCarrier::to_map(self : TextMapCarrier) -> Map[String, String] {
  let out : Map[String, String] = Map(
    [], capacity=map_capacity_for_entries(self.entries.length()),
  )
  for key, value in self.entries {
    out.set(key, value)
  }
  out
}
