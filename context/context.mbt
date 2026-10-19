// Immutable Context, modelled after the OpenTelemetry Context API.
//
// A Context carries the current SpanContext and string baggage values.
// Derived contexts form an immutable chain: writing never mutates the parent.
// Lookups walk from the innermost context outwards.

///|
pub struct Context {
  span_ctx : @api.SpanContext?
  key : String?
  value : String?
  // Baggage map carried by a single chain node, used by `with_baggage`.
  baggage_map : Map[String, String]?
  parent : Context?
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
  for key, value in values {
    baggage.set(key, value)
  }
  {
    span_ctx: None,
    key: None,
    value: None,
    baggage_map: Some(baggage),
    parent: Some(self),
  }
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
            for key, _ in map {
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
            for key, value in map {
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
