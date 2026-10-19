// Immutable Context, modelled after the OpenTelemetry Context API.
//
// A Context carries the current SpanContext and baggage values. Derived
// contexts form an immutable chain: writing never mutates the parent. Lookups
// walk from the innermost context outwards.

///|
pub struct Context {
  span_ctx : @api.SpanContext?
  key : String?
  value : String?
  // W3C baggage properties attached to the value of a single-entry node.
  properties : Array[(String, String)]?
  // Baggage map carried by a single chain node, used by `with_baggage`.
  baggage_map : Map[String, String]?
  parent : Context?
}

// One baggage member stored in a Context: a key, its value and the optional
// W3C baggage properties attached to it. The properties array is stored as
// given; callers must not mutate it afterwards.

///|
pub(all) struct BaggageEntry {
  key : String
  value : String
  properties : Array[(String, String)]
} derive(Eq, @debug.Debug)

// Create a baggage member with optional `key=value` properties.

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

// The empty root context.

///|
let root_context : Context = {
  span_ctx: None,
  key: None,
  value: None,
  properties: None,
  baggage_map: None,
  parent: None,
}

// An empty root context.

///|
pub fn Context::root() -> Context {
  root_context
}

// Derive a context carrying the given span.

///|
pub fn Context::with_span(self : Context, sc : @api.SpanContext) -> Context {
  {
    span_ctx: Some(sc),
    key: None,
    value: None,
    properties: None,
    baggage_map: None,
    parent: Some(self),
  }
}

// Derive a context carrying a string baggage value.

///|
pub fn Context::with_value(
  self : Context,
  key : String,
  value : String,
) -> Context {
  {
    span_ctx: None,
    key: Some(key),
    value: Some(value),
    properties: None,
    baggage_map: None,
    parent: Some(self),
  }
}

// Derive a context carrying a baggage value together with its W3C baggage
// properties. The properties array is stored as given; callers must not mutate
// it afterwards. An empty properties array is treated as no properties.

///|
pub fn Context::with_baggage_entry(
  self : Context,
  key : String,
  value : String,
  properties? : Array[(String, String)],
) -> Context {
  let properties = match properties {
    Some(values) => if values.length() == 0 { None } else { Some(values) }
    None => None
  }
  {
    span_ctx: None,
    key: Some(key),
    value: Some(value),
    properties,
    baggage_map: None,
    parent: Some(self),
  }
}

// Derive a context in which `key` no longer has a baggage value: values
// stored in outer contexts are hidden. A later `with_value` call can
// reintroduce the key.

///|
pub fn Context::without_value(self : Context, key : String) -> Context {
  {
    span_ctx: None,
    key: Some(key),
    value: None,
    properties: None,
    baggage_map: None,
    parent: Some(self),
  }
}

// Derive a context carrying every key/value pair of `values` as baggage.
// Pairs are applied in map order; lookups always see the innermost value.

///|
pub fn Context::with_baggage(
  self : Context,
  values : Map[String, String],
) -> Context {
  if values.length() == 0 {
    return self
  }
  let baggage : Map[String, String] = Map(
    [], capacity=map_capacity_for_entries(values.length()),
  )
  for entry in values.to_array() {
    let (key, value) = entry
    baggage.set(key, value)
  }
  {
    span_ctx: None,
    key: None,
    value: None,
    properties: None,
    baggage_map: Some(baggage),
    parent: Some(self),
  }
}

// Like `with_baggage`, but takes ownership of `values` instead of copying it.
// Callers must not mutate the map afterwards.

///|
pub fn Context::with_baggage_owned(
  self : Context,
  values : Map[String, String],
) -> Context {
  if values.length() == 0 {
    return self
  }
  {
    span_ctx: None,
    key: None,
    value: None,
    properties: None,
    baggage_map: Some(values),
    parent: Some(self),
  }
}

// Derive a context carrying every member of `entries`. Members are applied in
// order, so a later member overrides an earlier one with the same key. The
// property arrays are stored as given; callers must not mutate them
// afterwards.

///|
pub fn Context::with_baggage_entries(
  self : Context,
  entries : Array[BaggageEntry],
) -> Context {
  let mut context = self
  for entry in entries {
    context = context.with_baggage_entry(
      entry.key,
      entry.value,
      properties=entry.properties,
    )
  }
  context
}

// The nearest span context in the chain, if any.

///|
pub fn Context::span_context(self : Context) -> @api.SpanContext? {
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) =>
        match context.span_ctx {
          Some(sc) => return Some(sc)
          None => cursor = context.parent
        }
      None => break
    }
  }
  None
}

// Look up a baggage value, searching outer contexts last. A key removed with
// `without_value` resolves to `None` and hides values from outer contexts.

///|
pub fn Context::value(self : Context, key : String) -> String? {
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) =>
        match context.key {
          Some(entry_key) =>
            if entry_key == key {
              return context.value
            } else {
              cursor = context.parent
            }
          None =>
            match context.baggage_map {
              Some(map) =>
                match map.get(key) {
                  Some(value) => return Some(value)
                  None => cursor = context.parent
                }
              None => cursor = context.parent
            }
        }
      None => break
    }
  }
  None
}

// Look up a baggage member, including its W3C baggage properties. Returns
// `None` when the key is absent or was removed with `without_value`.

///|
pub fn Context::baggage_entry(self : Context, key : String) -> BaggageEntry? {
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) =>
        match context.key {
          Some(entry_key) =>
            if entry_key == key {
              match context.value {
                Some(value) =>
                  return Some({
                    key,
                    value,
                    properties: match context.properties {
                      Some(properties) => properties
                      None => []
                    },
                  })
                None => return None
              }
            } else {
              cursor = context.parent
            }
          None =>
            match context.baggage_map {
              Some(map) =>
                match map.get(key) {
                  Some(value) =>
                    return Some({ key, value, properties: [] })
                  None => cursor = context.parent
                }
              None => cursor = context.parent
            }
        }
      None => break
    }
  }
  None
}

// Flatten the baggage of the whole chain, innermost members winning and their
// properties preserved. Keys removed with `without_value` are excluded.
// Members are returned in chain order (innermost first).

///|
pub fn Context::baggage_entries(self : Context) -> Array[BaggageEntry] {
  let entries : Array[BaggageEntry] = []
  let values : Map[String, Bool] = Map([])
  let mut deleted : Map[String, Bool]? = None
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) => {
        match context.key {
          Some(key) => {
            let mut visible = values.get(key) is None
            if visible {
              match deleted {
                Some(removed) =>
                  if removed.get(key) is Some(_) {
                    visible = false
                  }
                None => ()
              }
            }
            if visible {
              match context.value {
                Some(value) => {
                  values.set(key, true)
                  entries.push({
                    key,
                    value,
                    properties: match context.properties {
                      Some(properties) => properties
                      None => []
                    },
                  })
                }
                None =>
                  match deleted {
                    Some(removed) => removed.set(key, true)
                    None => {
                      let removed : Map[String, Bool] = Map([])
                      removed.set(key, true)
                      deleted = Some(removed)
                    }
                  }
              }
            }
          }
          None => ()
        }
        match context.baggage_map {
          Some(map) =>
            for entry in map.to_array() {
              let (key, value) = entry
              let mut visible = values.get(key) is None
              if visible {
                match deleted {
                  Some(removed) =>
                    if removed.get(key) is Some(_) {
                      visible = false
                    }
                  None => ()
                }
              }
              if visible {
                values.set(key, true)
                entries.push({ key, value, properties: [] })
              }
            }
          None => ()
        }
        cursor = context.parent
      }
      None => break
    }
  }
  entries
}

// Whether the chain carries at least one visible baggage value. Keys removed
// with `without_value` do not count.

///|
pub fn Context::has_baggage(self : Context) -> Bool {
  let mut seen : Map[String, Bool]? = None
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) => {
        match context.key {
          Some(key) =>
            match seen {
              Some(keys) =>
                if keys.get(key) is None {
                  keys.set(key, true)
                  match context.value {
                    Some(_) => return true
                    None => ()
                  }
                }
              None =>
                match context.value {
                  Some(_) => return true
                  None => {
                    let keys : Map[String, Bool] = Map([])
                    keys.set(key, true)
                    seen = Some(keys)
                  }
                }
            }
          None => ()
        }
        match context.baggage_map {
          Some(map) =>
            for entry in map.to_array() {
              let (key, _) = entry
              match seen {
                Some(keys) =>
                  if keys.get(key) is None {
                    return true
                  }
                None => return true
              }
            }
          None => ()
        }
        cursor = context.parent
      }
      None => break
    }
  }
  false
}

// Flatten the baggage of the whole chain, innermost values winning. Keys
// removed with `without_value` are excluded.

///|
pub fn Context::baggage(self : Context) -> Map[String, String] {
  let values = Map([])
  let mut deleted : Map[String, Bool]? = None
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) => {
        match context.key {
          Some(key) => {
            let mut visible = values.get(key) is None
            if visible {
              match deleted {
                Some(removed) =>
                  if removed.get(key) is Some(_) {
                    visible = false
                  }
                None => ()
              }
            }
            if visible {
              match context.value {
                Some(value) => values.set(key, value)
                None =>
                  match deleted {
                    Some(removed) => removed.set(key, true)
                    None => {
                      let removed : Map[String, Bool] = Map([])
                      removed.set(key, true)
                      deleted = Some(removed)
                    }
                  }
              }
            }
          }
          None => ()
        }
        match context.baggage_map {
          Some(map) =>
            for entry in map.to_array() {
              let (key, value) = entry
              let mut visible = values.get(key) is None
              if visible {
                match deleted {
                  Some(removed) =>
                    if removed.get(key) is Some(_) {
                      visible = false
                    }
                  None => ()
                }
              }
              if visible {
                values.set(key, value)
              }
            }
          None => ()
        }
        cursor = context.parent
      }
      None => break
    }
  }
  values
}

// The parent context this context was derived from.

///|
pub fn Context::parent(self : Context) -> Context? {
  self.parent
}

///|
pub extend BaggageEntry with Eq::{not_equal, equal}

///|
pub extend BaggageEntry with @debug.Debug::{to_repr}
