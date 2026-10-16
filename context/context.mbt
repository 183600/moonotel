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

// An empty root context.
pub fn Context::root() -> Context {
  { span_ctx: None, key: None, value: None, parent: None }
}

// Derive a context carrying the given span.
pub fn Context::with_span(self : Context, sc : @api.SpanContext) -> Context {
  { span_ctx: Some(sc), key: None, value: None, parent: Some(self) }
}

// Derive a context carrying a string baggage value.
pub fn Context::with_value(self : Context, key : String, value : String) -> Context {
  { span_ctx: None, key: Some(key), value: Some(value), parent: Some(self) }
}

// The nearest span context in the chain, if any.
pub fn Context::span_context(self : Context) -> @api.SpanContext? {
  match self.span_ctx {
    Some(sc) => Some(sc)
    None =>
      match self.parent {
        Some(parent) => parent.span_context()
        None => None
      }
  }
}

// Look up a baggage value, searching outer contexts last.
pub fn Context::value(self : Context, key : String) -> String? {
  match (self.key, self.value) {
    (Some(entry_key), Some(entry_value)) =>
      if entry_key == key {
        Some(entry_value)
      } else {
        match self.parent {
          Some(parent) => parent.value(key)
          None => None
        }
      }
    _ =>
      match self.parent {
        Some(parent) => parent.value(key)
        None => None
      }
  }
}

// Flatten the baggage of the whole chain, innermost values winning.
pub fn Context::baggage(self : Context) -> Map[String, String] {
  let values = Map::new()
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
