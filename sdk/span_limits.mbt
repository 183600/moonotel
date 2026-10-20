// Collection limits for spans, following the OpenTelemetry SDK
// specification.
//
// The limits bound how many attributes, events and links a span records and
// how many attributes events and links may carry. Once a limit is reached the
// excess items are dropped and counted; the counts are surfaced through
// `SpanData` so exporters can report the OTLP `dropped_*_count` fields.
//
// A limit of `-1` means "no limit". The defaults match the specification:
// 128 attributes per span, 128 events per span, 128 links per span,
// 128 attributes per event and per link, and no attribute-value length limit.
// `from_env` reads the standard `OTEL_SPAN_*`, `OTEL_EVENT_*`,
// `OTEL_LINK_*` and `OTEL_ATTRIBUTE_*` environment variables.

///|
pub struct SpanLimits {
  attribute_count_limit : Int32
  event_count_limit : Int32
  link_count_limit : Int32
  event_attribute_count_limit : Int32
  link_attribute_count_limit : Int32
  // Maximum length of string attribute values; -1 disables truncation.
  attribute_value_length_limit : Int32
}

// Create span limits. Every parameter defaults to the value required by the
// specification; pass `-1` for "no limit".

///|
pub fn SpanLimits::new(
  attribute_count_limit? : Int32,
  event_count_limit? : Int32,
  link_count_limit? : Int32,
  event_attribute_count_limit? : Int32,
  link_attribute_count_limit? : Int32,
  attribute_value_length_limit? : Int32,
) -> SpanLimits {
  {
    attribute_count_limit: attribute_count_limit.unwrap_or(128),
    event_count_limit: event_count_limit.unwrap_or(128),
    link_count_limit: link_count_limit.unwrap_or(128),
    event_attribute_count_limit: event_attribute_count_limit.unwrap_or(128),
    link_attribute_count_limit: link_attribute_count_limit.unwrap_or(128),
    attribute_value_length_limit: attribute_value_length_limit.unwrap_or(-1),
  }
}

// Limits that drop nothing (every field is `-1`).

///|
pub fn SpanLimits::unlimited() -> SpanLimits {
  {
    attribute_count_limit: -1,
    event_count_limit: -1,
    link_count_limit: -1,
    event_attribute_count_limit: -1,
    link_attribute_count_limit: -1,
    attribute_value_length_limit: -1,
  }
}

// Maximum number of attributes recorded on one span (-1 = no limit).

///|
pub fn SpanLimits::attribute_count_limit(self : SpanLimits) -> Int32 {
  self.attribute_count_limit
}

// Maximum number of events recorded on one span (-1 = no limit).

///|
pub fn SpanLimits::event_count_limit(self : SpanLimits) -> Int32 {
  self.event_count_limit
}

// Maximum number of links recorded on one span (-1 = no limit).

///|
pub fn SpanLimits::link_count_limit(self : SpanLimits) -> Int32 {
  self.link_count_limit
}

// Maximum number of attributes recorded on one event (-1 = no limit).

///|
pub fn SpanLimits::event_attribute_count_limit(self : SpanLimits) -> Int32 {
  self.event_attribute_count_limit
}

// Maximum number of attributes recorded on one link (-1 = no limit).

///|
pub fn SpanLimits::link_attribute_count_limit(self : SpanLimits) -> Int32 {
  self.link_attribute_count_limit
}

// Maximum length of a string attribute value (-1 = no limit).

///|
pub fn SpanLimits::attribute_value_length_limit(self : SpanLimits) -> Int32 {
  self.attribute_value_length_limit
}

// Read a non-negative integer from an environment variable. An absent, empty,
// malformed or negative value yields `None`, as required by the specification.

///|
fn env_limit_opt(name : String) -> Int32? {
  match @env.get_env_var(name) {
    Some(value) => {
      let trimmed = value.trim()
      if trimmed == "" {
        None
      } else {
        match parse_decimal_int(trimmed) {
          Some(parsed) => if parsed < 0 { None } else { Some(parsed) }
          None => None
        }
      }
    }
    None => None
  }
}

// Read a non-negative integer, falling back to `default` when the variable is
// absent, empty, malformed or negative.

///|
fn env_limit(name : String, default : Int32) -> Int32 {
  match env_limit_opt(name) {
    Some(value) => value
    None => default
  }
}

// Read a non-negative integer from `name`, falling back to the generic
// `OTEL_ATTRIBUTE_COUNT_LIMIT` (then to 128) when the specific variable is
// absent, empty, malformed or negative.

///|
fn env_attribute_count_limit(name : String) -> Int32 {
  match env_limit_opt(name) {
    Some(value) => value
    None => env_limit("OTEL_ATTRIBUTE_COUNT_LIMIT", 128)
  }
}

// Build span limits from the standard environment variables:
//
// - `OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT`, falling back to
//   `OTEL_ATTRIBUTE_COUNT_LIMIT` (default 128)
// - `OTEL_SPAN_EVENT_COUNT_LIMIT` (default 128)
// - `OTEL_SPAN_LINK_COUNT_LIMIT` (default 128)
// - `OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT`, falling back to
//   `OTEL_ATTRIBUTE_COUNT_LIMIT` (default 128)
// - `OTEL_LINK_ATTRIBUTE_COUNT_LIMIT`, falling back to
//   `OTEL_ATTRIBUTE_COUNT_LIMIT` (default 128)
// - `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT`, falling back to
//   `OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT` (default: no limit)
//
// The span-specific attribute count and value length variables take
// precedence over their generic counterparts, `OTEL_ATTRIBUTE_COUNT_LIMIT`
// and `OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT`.

///|
pub fn SpanLimits::from_env() -> SpanLimits {
  let attribute_value_length_limit = match
    env_limit_opt("OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT") {
    Some(value) => value
    None => env_limit("OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT", -1)
  }
  {
    attribute_count_limit: env_attribute_count_limit(
      "OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT",
    ),
    event_count_limit: env_limit("OTEL_SPAN_EVENT_COUNT_LIMIT", 128),
    link_count_limit: env_limit("OTEL_SPAN_LINK_COUNT_LIMIT", 128),
    event_attribute_count_limit: env_attribute_count_limit(
      "OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT",
    ),
    link_attribute_count_limit: env_attribute_count_limit(
      "OTEL_LINK_ATTRIBUTE_COUNT_LIMIT",
    ),
    attribute_value_length_limit,
  }
}
