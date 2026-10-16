// Immutable Context, modelled after the OpenTelemetry Context API.
//
// A Context carries the current SpanContext and string baggage values.
// Derived contexts form an immutable chain: writing never mutates the parent.
// Lookups walk from the innermost context outwards.

pub struct Context {
  span_ctx : @api.SpanContext?
  key : String?
  value : String?
  parent : Context?
}

// The empty root context. `Context` is immutable, so one shared instance can
// serve every caller and avoid an allocation per lookup.
let root_context : Context = { span_ctx: None, key: None, value: None, parent: None }

// An empty root context.
pub fn Context::root() -> Context {
  root_context
}

// Derive a context carrying the given span.
pub fn Context::with_span(self : Context, sc : @api.SpanContext) -> Context {
  { span_ctx: Some(sc), key: None, value: None, parent: Some(self) }
}

// Derive a context carrying a string baggage value.
pub fn Context::with_value(self : Context, key : String, value : String) -> Context {
  { span_ctx: None, key: Some(key), value: Some(value), parent: Some(self) }
}

// Derive a context carrying every key/value pair of `values` as baggage.
// Pairs are applied in map order; lookups always see the innermost value.
pub fn Context::with_baggage(
  self : Context,
  values : Map[String, String]
) -> Context {
  let mut result = self
  values.each(fn(key, value) { result = result.with_value(key, value) })
  result
}

// The nearest span context in the chain, if any.
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

// Look up a baggage value, searching outer contexts last.
pub fn Context::value(self : Context, key : String) -> String? {
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) =>
        match (context.key, context.value) {
          (Some(entry_key), Some(entry_value)) =>
            if entry_key == key {
              return Some(entry_value)
            } else {
              cursor = context.parent
            }
          _ => cursor = context.parent
        }
      None => break
    }
  }
  None
}

// Whether the chain carries at least one baggage value. Cheaper than
// flattening the baggage when only presence matters.
pub fn Context::has_baggage(self : Context) -> Bool {
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) =>
        match (context.key, context.value) {
          (Some(_), Some(_)) => return true
          _ => cursor = context.parent
        }
      None => break
    }
  }
  false
}

// Flatten the baggage of the whole chain, innermost values winning.
pub fn Context::baggage(self : Context) -> Map[String, String] {
  let values = Map([])
  let mut cursor : Context? = Some(self)
  while true {
    match cursor {
      Some(context) => {
        match (context.key, context.value) {
          (Some(key), Some(value)) =>
            if values.get(key) is None {
              values.set(key, value)
            }
          _ => ()
        }
        cursor = context.parent
      }
      None => break
    }
  }
  values
}

// The parent context this context was derived from.
pub fn Context::parent(self : Context) -> Context? {
  self.parent
}
