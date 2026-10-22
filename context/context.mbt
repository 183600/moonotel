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
  // Baggage members carried by this context node, used by
  // `with_baggage_entries`.
  baggage_list : Array[BaggageEntry]?
  // When set, every baggage value stored in an outer node is hidden. This is
  // the marker installed by `without_baggage` and by an empty baggage update.
  clear_baggage : Bool
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
  baggage_list: None,
  clear_baggage: false,
  parent: None,
}

// An empty root context.

///|
pub fn Context::root() -> Context {
  root_context
}

// Derive a context carrying the given span. The context owns a copy of the
// SpanContext, so later mutations through the caller's ID views cannot change
// it.

///|
pub fn Context::with_span(self : Context, sc : @api.SpanContext) -> Context {
  {
    span_ctx: Some(sc.copy()),
    key: None,
    value: None,
    properties: None,
    baggage_map: None,
    baggage_list: None,
    clear_baggage: false,
    parent: Some(self),
  }
}

// Derive a context carrying a string baggage value. An empty name is not a
// valid baggage name, as required by the OpenTelemetry Baggage API, so it is
// ignored and leaves the context unchanged.

///|
pub fn Context::with_value(
  self : Context,
  key : String,
  value : String,
) -> Context {
  if key == "" {
    return self
  }
  {
    span_ctx: None,
    key: Some(key),
    value: Some(value),
    properties: None,
    baggage_map: None,
    baggage_list: None,
    clear_baggage: false,
    parent: Some(self),
  }
}

// Derive a context carrying a baggage value together with its W3C baggage
// properties. A copy of the properties array is stored, so mutating the
// caller's array cannot change the immutable context. An empty properties
// array is treated as no properties. An empty name is invalid and ignored.

///|
pub fn Context::with_baggage_entry(
  self : Context,
  key : String,
  value : String,
  properties? : Array[(String, String)],
) -> Context {
  if key == "" {
    return self
  }
  let properties = match properties {
    Some(values) =>
      if values.length() == 0 {
        None
      } else {
        Some(values.copy())
      }
    None => None
  }
  {
    span_ctx: None,
    key: Some(key),
    value: Some(value),
    properties,
    baggage_map: None,
    baggage_list: None,
    clear_baggage: false,
    parent: Some(self),
  }
}

// Derive a context in which `key` no longer has a baggage value: values
// stored in outer contexts are hidden. A later `with_value` call can
// reintroduce the key. An empty name is invalid and leaves the context
// unchanged.

///|
pub fn Context::without_value(self : Context, key : String) -> Context {
  if key == "" {
    return self
  }
  {
    span_ctx: None,
    key: Some(key),
    value: None,
    properties: None,
    baggage_map: None,
    baggage_list: None,
    clear_baggage: false,
    parent: Some(self),
  }
}

// Derive a context in which no baggage value is visible: every value stored in
// an outer context is hidden, including keys added later only if they are added
// to the derived context itself. A later `with_value`/`with_baggage` call can
// introduce new members.

///|
pub fn Context::without_baggage(self : Context) -> Context {
  {
    span_ctx: None,
    key: None,
    value: None,
    properties: None,
    baggage_map: None,
    baggage_list: None,
    clear_baggage: true,
    parent: Some(self),
  }
}

// Derive a context carrying every key/value pair of `values` as baggage.
// Pairs are applied in map order; lookups always see the innermost value.
// An empty baggage map clears every value stored in outer contexts, as before.
// Empty names are invalid and are skipped; when no valid pair remains the
// context is left unchanged.

///|
pub fn Context::with_baggage(
  self : Context,
  values : Map[String, String],
) -> Context {
  if values.length() == 0 {
    return self.without_baggage()
  }
  let baggage : Map[String, String] = Map(
    [], capacity=map_capacity_for_entries(values.length()),
  )
  for key, value in values {
    if key != "" {
      baggage.set(key, value)
    }
  }
  if baggage.length() == 0 {
    return self
  }
  {
    span_ctx: None,
    key: None,
    value: None,
    properties: None,
    baggage_map: Some(baggage),
    baggage_list: None,
    clear_baggage: false,
    parent: Some(self),
  }
}

// Like `with_baggage`, but takes ownership of `values` instead of copying it.
// Callers must not mutate the map afterwards. Empty names are invalid and are
// skipped exactly like `with_baggage`.

///|
pub fn Context::with_baggage_owned(
  self : Context,
  values : Map[String, String],
) -> Context {
  if values.length() == 0 {
    return self.without_baggage()
  }
  let mut has_valid = false
  let mut has_empty = false
  for key, _ in values {
    if key == "" {
      has_empty = true
    } else {
      has_valid = true
    }
  }
  if !has_valid {
    return self
  }
  let baggage : Map[String, String] = if has_empty {
    // Taking ownership cannot skip an invalid entry, so filter into a fresh
    // map. This only happens for the invalid-input path.
    let filtered : Map[String, String] = Map(
      [], capacity=map_capacity_for_entries(values.length()),
    )
    for key, value in values {
      if key != "" {
        filtered.set(key, value)
      }
    }
    filtered
  } else {
    values
  }
  {
    span_ctx: None,
    key: None,
    value: None,
    properties: None,
    baggage_map: Some(baggage),
    baggage_list: None,
    clear_baggage: false,
    parent: Some(self),
  }
}

// Derive a context carrying every member of `entries`. Members are applied in
// order, so a later member overrides an earlier one with the same key. Each
// member and its properties are copied, so mutating the caller's arrays cannot
// change the immutable context. An empty name is invalid and is skipped; an
// empty entries array still clears the outer baggage, while an array whose
// members are all invalid leaves the context unchanged.

///|
pub fn Context::with_baggage_entries(
  self : Context,
  entries : Array[BaggageEntry],
) -> Context {
  if entries.length() == 0 {
    return self.without_baggage()
  }
  // Walking from the last entry to the first keeps the innermost occurrence of
  // each key; the result is ordered from innermost to outermost.
  let list : Array[BaggageEntry] = Array(capacity=entries.length())
  let mut i = entries.length() - 1
  while i >= 0 {
    let entry = entries.unsafe_get(i)
    if entry.key == "" {
      i = i - 1
      continue
    }
    let mut duplicate = false
    for existing in list {
      if existing.key == entry.key {
        duplicate = true
        break
      }
    }
    if !duplicate {
      list.push({ ..entry, properties: entry.properties.copy() })
    }
    i = i - 1
  }
  if list.length() == 0 {
    return self
  }
  {
    span_ctx: None,
    key: None,
    value: None,
    properties: None,
    baggage_map: None,
    baggage_list: Some(list),
    clear_baggage: false,
    parent: Some(self),
  }
}

// Overlay all baggage stored in `other` onto this context. Unlike
// `with_baggage_entries`, which only receives the visible members, this copies
// the baggage nodes of `other` verbatim, including `without_value` removal
// markers. A later context therefore wins for the same key even when its
// winning value is an explicit removal. The span context of `other` is
// ignored; the span of this context is preserved.

///|
pub fn Context::with_baggage_from(
  self : Context,
  other : Context,
) -> Context {
  // Collect the baggage-bearing nodes of `other` from innermost to outermost,
  // then attach them in the opposite order so that `other`'s innermost node
  // is looked up first after the merge.
  let nodes : Array[Context] = []
  let mut cursor : Context? = Some(other)
  while true {
    match cursor {
      Some(context) => {
        let has_baggage = context.key is Some(_) ||
          context.baggage_map is Some(_) ||
          context.baggage_list is Some(_) ||
          context.clear_baggage
        if has_baggage {
          nodes.push(context)
        }
        // A clear marker hides every outer node, so they cannot contribute to
        // the merged context.
        if context.clear_baggage {
          break
        }
        cursor = context.parent
      }
      None => break
    }
  }
  let mut result = self
  let mut i = nodes.length() - 1
  while i >= 0 {
    let node = nodes.unsafe_get(i)
    result = {
      span_ctx: None,
      key: node.key,
      value: node.value,
      properties: match node.properties {
        Some(properties) => Some(properties.copy())
        None => None
      },
      baggage_map: node.baggage_map,
      baggage_list: node.baggage_list,
      clear_baggage: node.clear_baggage,
      parent: Some(result),
    }
    i = i - 1
  }
  result
}

// The nearest span context in the chain, if any, as a copy: mutating its ID
// arrays cannot change the context or other values derived from it.

///|
pub fn Context::span_context(self : Context) -> @api.SpanContext? {
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) =>
        match context.span_ctx {
          Some(sc) => return Some(sc.copy())
          None => cursor = context.parent
        }
      None => break
    }
  }
  None
}

// Copy a baggage entry and its mutable properties array.

///|
fn copy_baggage_entry(entry : BaggageEntry) -> BaggageEntry {
  { ..entry, properties: entry.properties.copy() }
}

// The member of `list` stored under `key`, if any, as a copy.

///|
fn baggage_list_entry(
  list : Array[BaggageEntry],
  key : String,
) -> BaggageEntry? {
  for entry in list {
    if entry.key == key {
      return Some(copy_baggage_entry(entry))
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
      Some(context) => {
        if context.clear_baggage {
          return None
        }
        match context.key {
          Some(entry_key) =>
            if entry_key == key {
              return context.value
            } else {
              cursor = context.parent
            }
          None => {
            match context.baggage_map {
              Some(map) =>
                match map.get(key) {
                  Some(value) => return Some(value)
                  None => ()
                }
              None => ()
            }
            match context.baggage_list {
              Some(list) =>
                match baggage_list_entry(list, key) {
                  Some(entry) => return Some(entry.value)
                  None => cursor = context.parent
                }
              None => cursor = context.parent
            }
          }
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
      Some(context) => {
        if context.clear_baggage {
          return None
        }
        match context.key {
          Some(entry_key) =>
            if entry_key == key {
              match context.value {
                Some(value) =>
                  return Some({
                    key,
                    value,
                    properties: match context.properties {
                      Some(properties) => properties.copy()
                      None => []
                    },
                  })
                None => return None
              }
            } else {
              cursor = context.parent
            }
          None => {
            let found : BaggageEntry? = match context.baggage_map {
              Some(map) =>
                match map.get(key) {
                  Some(value) => Some({ key, value, properties: [] })
                  None => None
                }
              None => None
            }
            let found = match found {
              Some(_) => found
              None =>
                match context.baggage_list {
                  Some(list) => baggage_list_entry(list, key)
                  None => None
                }
            }
            match found {
              Some(entry) => return Some(entry)
              None => cursor = context.parent
            }
          }
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
  // Keys whose innermost occurrence is a `without_value` marker.
  let deleted : Array[String] = []
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) => {
        if context.clear_baggage {
          break
        }
        match context.key {
          Some(key) => {
            let mut visible = true
            for existing in entries {
              if existing.key == key {
                visible = false
                break
              }
            }
            if visible {
              for removed in deleted {
                if removed == key {
                  visible = false
                  break
                }
              }
            }
            if visible {
              match context.value {
                Some(value) =>
                  entries.push({
                    key,
                    value,
                    properties: match context.properties {
                      Some(properties) => properties.copy()
                      None => []
                    },
                  })
                None => deleted.push(key)
              }
            }
          }
          None => ()
        }
        match context.baggage_map {
          Some(map) =>
            for key, value in map {
              let mut visible = true
              for existing in entries {
                if existing.key == key {
                  visible = false
                  break
                }
              }
              if visible {
                for removed in deleted {
                  if removed == key {
                    visible = false
                    break
                  }
                }
              }
              if visible {
                entries.push({ key, value, properties: [] })
              }
            }
          None => ()
        }
        match context.baggage_list {
          Some(list) =>
            for entry in list {
              let mut visible = true
              for existing in entries {
                if existing.key == entry.key {
                  visible = false
                  break
                }
              }
              if visible {
                for removed in deleted {
                  if removed == entry.key {
                    visible = false
                    break
                  }
                }
              }
              if visible {
                entries.push(copy_baggage_entry(entry))
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
  let deleted : Array[String] = []
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) => {
        if context.clear_baggage {
          return false
        }
        match context.key {
          Some(key) => {
            let mut removed = false
            for candidate in deleted {
              if candidate == key {
                removed = true
                break
              }
            }
            if !removed {
              match context.value {
                Some(_) => return true
                None => deleted.push(key)
              }
            }
          }
          None => ()
        }
        match context.baggage_map {
          Some(map) =>
            for key, _ in map {
              let mut removed = false
              for candidate in deleted {
                if candidate == key {
                  removed = true
                  break
                }
              }
              if !removed {
                return true
              }
            }
          None => ()
        }
        match context.baggage_list {
          Some(list) =>
            for entry in list {
              let mut removed = false
              for candidate in deleted {
                if candidate == entry.key {
                  removed = true
                  break
                }
              }
              if !removed {
                return true
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
  let deleted : Array[String] = []
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) => {
        if context.clear_baggage {
          break
        }
        match context.key {
          Some(key) =>
            if values.get(key) is None {
              let mut removed = false
              for candidate in deleted {
                if candidate == key {
                  removed = true
                  break
                }
              }
              if !removed {
                match context.value {
                  Some(value) => values.set(key, value)
                  None => deleted.push(key)
                }
              }
            }
          None => ()
        }
        match context.baggage_map {
          Some(map) =>
            for key, value in map {
              if values.get(key) is None {
                let mut removed = false
                for candidate in deleted {
                  if candidate == key {
                    removed = true
                    break
                  }
                }
                if !removed {
                  values.set(key, value)
                }
              }
            }
          None => ()
        }
        match context.baggage_list {
          Some(list) =>
            for entry in list {
              if values.get(entry.key) is None {
                let mut removed = false
                for candidate in deleted {
                  if candidate == entry.key {
                    removed = true
                    break
                  }
                }
                if !removed {
                  values.set(entry.key, entry.value)
                }
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
