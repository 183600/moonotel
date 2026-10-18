// The SDK Span implementation and the immutable SpanData snapshot that is
// handed to span processors and exporters.

// Value of a span attribute. The array forms map to the OTLP
// `AnyValue.array_value` field.

///|
pub(all) enum AttributeValue {
  StringValue(String)
  BoolValue(Bool)
  IntValue(Int64)
  DoubleValue(Double)
  StringArrayValue(Array[String])
  BoolArrayValue(Array[Bool])
  IntArrayValue(Array[Int64])
  DoubleArrayValue(Array[Double])
} derive(Eq, @debug.Debug)

// A timestamped event attached to a span. `dropped_attributes_count` is the
// number of attributes discarded because of the event attribute limit.

///|
pub(all) struct SpanEvent {
  name : String
  time_unix_nano : Int64
  attributes : Map[String, AttributeValue]
  dropped_attributes_count : Int32
}

// A link from a span to another span in a (possibly different) trace.
// `dropped_attributes_count` is the number of attributes discarded because of
// the link attribute limit.

///|
pub(all) struct SpanLink {
  span_context : @api.SpanContext
  attributes : Map[String, AttributeValue]
  dropped_attributes_count : Int32
}

// Create a link to `span_context` with optional attributes.

///|
pub fn SpanLink::new(
  span_context : @api.SpanContext,
  attributes? : Map[String, AttributeValue],
) -> SpanLink {
  {
    span_context,
    attributes: match attributes {
      Some(values) => values
      None => Map([], capacity=1)
    },
    dropped_attributes_count: 0,
  }
}

// Immutable snapshot of a span, produced when the span ends.

///|
pub(all) struct SpanData {
  name : String
  span_context : @api.SpanContext
  parent_span_id : Array[Int32]
  kind : @api.SpanKind
  start_time_unix_nano : Int64
  end_time_unix_nano : Int64
  attributes : Map[String, AttributeValue]
  events : Array[SpanEvent]
  links : Array[SpanLink]
  dropped_attributes_count : Int32
  dropped_events_count : Int32
  dropped_links_count : Int32
  status : @api.StatusCode
  status_description : String
  resource : Map[String, AttributeValue]
  scope_name : String
  scope_version : String
}

// Current wall-clock time in nanoseconds since the Unix epoch.

///|
fn unix_nano_now() -> Int64 {
  (@env.now() * 1000000).reinterpret_as_int64()
}

// Wall-clock milliseconds read by the span `end` call that is currently
// notifying processors. `end_clock_fresh` is true only while that
// notification runs.

///|
let end_clock_millis : Ref[UInt64] = Ref(0)

///|
let end_clock_fresh : Ref[Bool] = Ref(false)

// The current wall-clock milliseconds.

///|
fn current_millis() -> UInt64 {
  if end_clock_fresh.val {
    end_clock_millis.val
  } else {
    @env.now()
  }
}

// A recording span. Non-recording spans (sampler decision DROP) discard
// attributes and events and are never exported.

///|
pub struct SpanSdk {
  mut name : String
  context : @api.SpanContext
  parent_span_id : Array[Int32]
  kind : @api.SpanKind
  start_time_unix_nano : Int64
  mut end_time_unix_nano : Int64
  mut ended : Bool
  recording : Bool
  mut attributes : Map[String, AttributeValue]?
  mut events : Array[SpanEvent]?
  mut links : Array[SpanLink]?
  mut status : @api.StatusCode
  mut status_description : String
  limits : SpanLimits
  mut dropped_attributes : Int32
  mut dropped_events : Int32
  mut dropped_links : Int32
  processors : Array[&SpanProcessor]
  resource : Map[String, AttributeValue]
  scope_name : String
  scope_version : String
}

///|
fn create_span(
  name : String,
  context : @api.SpanContext,
  parent_span_id : Array[Int32],
  kind : @api.SpanKind,
  start_time_unix_nano : Int64,
  recording : Bool,
  links : Array[SpanLink]?,
  limits : SpanLimits,
  processors : Array[&SpanProcessor],
  resource : Map[String, AttributeValue],
  scope_name : String,
  scope_version : String,
) -> SpanSdk {
  let span : SpanSdk = {
    name,
    context,
    parent_span_id,
    kind,
    start_time_unix_nano,
    end_time_unix_nano: 0,
    ended: false,
    recording,
    attributes: None,
    events: None,
    links: None,
    status: @api.StatusCode::Unset,
    status_description: "",
    limits,
    dropped_attributes: 0,
    dropped_events: 0,
    dropped_links: 0,
    processors,
    resource,
    scope_name,
    scope_version,
  }
  // Links provided at span creation are subject to the same limits as links
  // added later; invalid links are ignored.
  match links {
    Some(values) =>
      for link in values {
        span.add_link(link)
      }
    None => ()
  }
  span
}

// Allocate the attribute map on first use.

///|
fn SpanSdk::mutable_attributes(self : SpanSdk) -> Map[String, AttributeValue] {
  match self.attributes {
    Some(attributes) => attributes
    None => {
      let attributes : Map[String, AttributeValue] = Map([])
      self.attributes = Some(attributes)
      attributes
    }
  }
}

// Allocate the event array on first use.

///|
fn SpanSdk::mutable_events(self : SpanSdk) -> Array[SpanEvent] {
  match self.events {
    Some(events) => events
    None => {
      let events : Array[SpanEvent] = []
      self.events = Some(events)
      events
    }
  }
}

// Allocate the link array on first use.

///|
fn SpanSdk::mutable_links(self : SpanSdk) -> Array[SpanLink] {
  match self.links {
    Some(links) => links
    None => {
      let links : Array[SpanLink] = []
      self.links = Some(links)
      links
    }
  }
}

// Whether a collection has room for one more element under `limit` (-1 means
// no limit).

///|
fn within_limit(size : Int32, limit : Int32) -> Bool {
  limit < 0 || size < limit
}

// Truncate a string to at most `limit` characters (code points). A limit of
// 0 yields the empty string; a negative limit returns the value unchanged. A
// surrogate pair is never split.

///|
fn truncate_string(value : String, limit : Int32) -> String {
  if limit < 0 {
    return value
  }
  let len = value.length()
  if len <= limit {
    return value
  }
  let end = if limit <= 0 {
    0
  } else {
    let last = value.unsafe_get(limit - 1).to_int()
    if last >= 0xD800 && last <= 0xDBFF {
      // The character at `limit` is a high surrogate: keep the whole pair
      // when its low surrogate follows, otherwise drop the lone surrogate.
      if limit < len &&
        value.unsafe_get(limit).to_int() >= 0xDC00 &&
        value.unsafe_get(limit).to_int() <= 0xDFFF {
        limit + 1
      } else {
        limit - 1
      }
    } else {
      limit
    }
  }
  value[:end].to_owned()
}

// Apply the attribute value length limit to a value. String values (and the
// elements of string arrays) are truncated; other value kinds are unchanged.

///|
fn truncate_attribute_value(
  value : AttributeValue,
  limit : Int32,
) -> AttributeValue {
  if limit < 0 {
    return value
  }
  match value {
    StringValue(text) => StringValue(truncate_string(text, limit))
    StringArrayValue(items) => {
      let out : Array[String] = []
      for item in items {
        out.push(truncate_string(item, limit))
      }
      StringArrayValue(out)
    }
    _ => value
  }
}

// Copy `attributes` under the event/link attribute count and value length
// limits. Returns the kept attributes and how many were dropped.

///|
fn limited_attributes(
  attributes : Map[String, AttributeValue],
  count_limit : Int32,
  value_length_limit : Int32,
) -> (Map[String, AttributeValue], Int32) {
  let total = attributes.length()
  let capacity = if count_limit < 0 || count_limit > total {
    total
  } else {
    count_limit
  }
  let kept : Map[String, AttributeValue] = Map([], capacity=capacity * 2)
  let mut dropped = 0
  for key, value in attributes.iter2() {
    if within_limit(kept.length(), count_limit) {
      kept.set(key, truncate_attribute_value(value, value_length_limit))
    } else {
      dropped = dropped + 1
    }
  }
  (kept, dropped)
}

// Record one attribute unless the count limit is reached; `key` may overwrite
// an existing attribute without counting against the limit.

///|
fn SpanSdk::set_attribute_limited(
  self : SpanSdk,
  key : String,
  value : AttributeValue,
) -> Unit {
  let attributes = self.mutable_attributes()
  if within_limit(attributes.length(), self.limits.attribute_count_limit) {
    attributes.set(
      key,
      truncate_attribute_value(value, self.limits.attribute_value_length_limit),
    )
  } else {
    match attributes.get(key) {
      Some(_) =>
        attributes.set(
          key,
          truncate_attribute_value(
            value,
            self.limits.attribute_value_length_limit,
          ),
        )
      None => self.dropped_attributes = self.dropped_attributes + 1
    }
  }
}

// The SpanContext of this span.

///|
pub fn SpanSdk::context(self : SpanSdk) -> @api.SpanContext {
  self.context
}

// Whether the span records attributes and events. Following the
// specification, an ended span is no longer recording.

///|
pub fn SpanSdk::is_recording(self : SpanSdk) -> Bool {
  self.recording && !self.ended
}

// Whether the span has already ended.

///|
pub fn SpanSdk::is_ended(self : SpanSdk) -> Bool {
  self.ended
}

// The span kind.

///|
pub fn SpanSdk::kind(self : SpanSdk) -> @api.SpanKind {
  self.kind
}

// The span name.

///|
pub fn SpanSdk::name(self : SpanSdk) -> String {
  self.name
}

// The span start time in nanoseconds since the Unix epoch.

///|
pub fn SpanSdk::start_time_unix_nano(self : SpanSdk) -> Int64 {
  self.start_time_unix_nano
}

// The span end time in nanoseconds since the Unix epoch (0 while running).

///|
pub fn SpanSdk::end_time_unix_nano(self : SpanSdk) -> Int64 {
  self.end_time_unix_nano
}

// The parent span ID, or an empty array for root spans.

///|
pub fn SpanSdk::parent_span_id(self : SpanSdk) -> Array[Int32] {
  self.parent_span_id.copy()
}

// The recorded attributes (empty for non-recording spans).

///|
pub fn SpanSdk::attributes(self : SpanSdk) -> Map[String, AttributeValue] {
  self.mutable_attributes()
}

// The recorded events (empty for non-recording spans).

///|
pub fn SpanSdk::events(self : SpanSdk) -> Array[SpanEvent] {
  self.mutable_events()
}

// The links of this span.

///|
pub fn SpanSdk::links(self : SpanSdk) -> Array[SpanLink] {
  self.mutable_links()
}

// The collection limits this span enforces.

///|
pub fn SpanSdk::limits(self : SpanSdk) -> SpanLimits {
  self.limits
}

// Number of attributes discarded because of the attribute count limit.

///|
pub fn SpanSdk::dropped_attributes_count(self : SpanSdk) -> Int32 {
  self.dropped_attributes
}

// Number of events discarded because of the event count limit.

///|
pub fn SpanSdk::dropped_events_count(self : SpanSdk) -> Int32 {
  self.dropped_events
}

// Number of links discarded because of the link count limit.

///|
pub fn SpanSdk::dropped_links_count(self : SpanSdk) -> Int32 {
  self.dropped_links
}

// The current span status.

///|
pub fn SpanSdk::status(self : SpanSdk) -> @api.StatusCode {
  self.status
}

// The human-readable description associated with the status.

///|
pub fn SpanSdk::status_description(self : SpanSdk) -> String {
  self.status_description
}

// Update the span name. No-op for non-recording or ended spans.

///|
pub fn SpanSdk::update_name(self : SpanSdk, name : String) -> Unit {
  if self.recording && !self.ended {
    self.name = name
  }
}

// Set a single attribute. No-op for non-recording or ended spans. When the
// attribute count limit is reached, the attribute is dropped and counted.
// String values are truncated to the configured value length limit.

///|
pub fn SpanSdk::set_attribute(
  self : SpanSdk,
  key : String,
  value : AttributeValue,
) -> Unit {
  if self.recording && !self.ended {
    self.set_attribute_limited(key, value)
  }
}

// Set multiple attributes. No-op for non-recording or ended spans. Every
// attribute is subject to the same count and value length limits as
// `set_attribute`.

///|
pub fn SpanSdk::set_attributes(
  self : SpanSdk,
  attributes : Map[String, AttributeValue],
) -> Unit {
  if self.recording && !self.ended {
    if self.attributes is None && attributes.length() > 0 {
      let limit = self.limits.attribute_count_limit
      let budget = if limit >= 0 && limit < attributes.length() {
        limit
      } else {
        attributes.length()
      }
      if budget > 0 {
        self.attributes = Some(Map([], capacity=budget * 2))
      }
    }
    attributes.each(fn(key, value) { self.set_attribute_limited(key, value) })
  }
}

// Set a string attribute. Equivalent to `set_attribute(key, StringValue(...))`
// and subject to the same count and value length limits.

///|
pub fn SpanSdk::set_string_attribute(
  self : SpanSdk,
  key : String,
  value : String,
) -> Unit {
  self.set_attribute(key, StringValue(value))
}

// Set a boolean attribute. Equivalent to
// `set_attribute(key, BoolValue(...))`.

///|
pub fn SpanSdk::set_bool_attribute(
  self : SpanSdk,
  key : String,
  value : Bool,
) -> Unit {
  self.set_attribute(key, BoolValue(value))
}

// Set a 64-bit integer attribute. Equivalent to
// `set_attribute(key, IntValue(...))`.

///|
pub fn SpanSdk::set_int_attribute(
  self : SpanSdk,
  key : String,
  value : Int64,
) -> Unit {
  self.set_attribute(key, IntValue(value))
}

// Set a double attribute. Equivalent to
// `set_attribute(key, DoubleValue(...))`.

///|
pub fn SpanSdk::set_double_attribute(
  self : SpanSdk,
  key : String,
  value : Double,
) -> Unit {
  self.set_attribute(key, DoubleValue(value))
}

// Set a string array attribute. Equivalent to
// `set_attribute(key, StringArrayValue(...))`; every element is subject to the
// same count and value length limits as `set_string_attribute`.

///|
pub fn SpanSdk::set_string_array_attribute(
  self : SpanSdk,
  key : String,
  value : Array[String],
) -> Unit {
  self.set_attribute(key, StringArrayValue(value))
}

// Set an integer array attribute. Equivalent to
// `set_attribute(key, IntArrayValue(...))`.

///|
pub fn SpanSdk::set_int_array_attribute(
  self : SpanSdk,
  key : String,
  value : Array[Int64],
) -> Unit {
  self.set_attribute(key, IntArrayValue(value))
}

// Set a boolean array attribute. Equivalent to
// `set_attribute(key, BoolArrayValue(...))`.

///|
pub fn SpanSdk::set_bool_array_attribute(
  self : SpanSdk,
  key : String,
  value : Array[Bool],
) -> Unit {
  self.set_attribute(key, BoolArrayValue(value))
}

// Set a double array attribute. Equivalent to
// `set_attribute(key, DoubleArrayValue(...))`.

///|
pub fn SpanSdk::set_double_array_attribute(
  self : SpanSdk,
  key : String,
  value : Array[Double],
) -> Unit {
  self.set_attribute(key, DoubleArrayValue(value))
}

// Add an event to the span. No-op for non-recording or ended spans. When the
// event count limit is reached the event is dropped and counted; attributes
// beyond the event attribute count limit are dropped and counted on the
// event.

///|
pub fn SpanSdk::add_event(
  self : SpanSdk,
  name : String,
  attributes? : Map[String, AttributeValue],
  time_unix_nano? : Int64,
) -> Unit {
  if self.recording && !self.ended {
    if !within_limit(self.event_count(), self.limits.event_count_limit) {
      self.dropped_events = self.dropped_events + 1
      return
    }
    let timestamp = match time_unix_nano {
      Some(value) => value
      None => unix_nano_now()
    }
    let (event_attributes, dropped) = match attributes {
      Some(map) =>
        limited_attributes(
          map,
          self.limits.event_attribute_count_limit,
          self.limits.attribute_value_length_limit,
        )
      None => (Map([], capacity=1), 0)
    }
    self
    .mutable_events()
    .push({
      name,
      time_unix_nano: timestamp,
      attributes: event_attributes,
      dropped_attributes_count: dropped,
    })
  }
}

// Number of events already recorded.

///|
fn SpanSdk::event_count(self : SpanSdk) -> Int32 {
  match self.events {
    Some(events) => events.length()
    None => 0
  }
}

// Number of links already recorded.

///|
fn SpanSdk::link_count(self : SpanSdk) -> Int32 {
  match self.links {
    Some(links) => links.length()
    None => 0
  }
}

// Add a link to another span. Links with an invalid SpanContext are
// ignored. No-op for non-recording or ended spans. When the link count limit
// is reached the link is dropped and counted; attributes beyond the link
// attribute count limit are dropped and counted on the link.

///|
pub fn SpanSdk::add_link(self : SpanSdk, link : SpanLink) -> Unit {
  if self.recording && !self.ended && link.span_context.is_valid() {
    if !within_limit(self.link_count(), self.limits.link_count_limit) {
      self.dropped_links = self.dropped_links + 1
      return
    }
    let (link_attributes, dropped) = limited_attributes(
      link.attributes,
      self.limits.link_attribute_count_limit,
      self.limits.attribute_value_length_limit,
    )
    self
    .mutable_links()
    .push({
      span_context: link.span_context,
      attributes: link_attributes,
      dropped_attributes_count: dropped,
    })
  }
}

// Record an exception as an `exception` event, following the OpenTelemetry
// semantic conventions (`exception.type` / `exception.message`).
// No-op for non-recording or ended spans.

///|
pub fn SpanSdk::record_exception(
  self : SpanSdk,
  error : Error,
  exception_type? : String,
  time_unix_nano? : Int64,
) -> Unit {
  if self.recording && !self.ended {
    let message = @debug.to_string(error)
    let type_name = match exception_type {
      Some(value) => value
      None => error.to_string()
    }
    let attributes : Map[String, AttributeValue] = Map([
      (EXCEPTION_TYPE, StringValue(type_name)),
      (EXCEPTION_MESSAGE, StringValue(message)),
    ])
    self.add_event("exception", attributes~, time_unix_nano?)
  }
}

// Set the span status. No-op for non-recording or ended spans.
//
// Status follows the OpenTelemetry total order `Ok > Error > Unset`: `Ok` is
// final, an `Unset` attempt is ignored, and a description is only recorded
// together with `Error`.

///|
pub fn SpanSdk::set_status(
  self : SpanSdk,
  status : @api.StatusCode,
  description? : String,
) -> Unit {
  if self.recording && !self.ended {
    match status {
      @api.StatusCode::Unset => ()
      @api.StatusCode::Ok => {
        self.status = @api.StatusCode::Ok
        self.status_description = ""
      }
      @api.StatusCode::Error =>
        if self.status != @api.StatusCode::Ok {
          self.status = @api.StatusCode::Error
          self.status_description = description.unwrap_or("")
        }
    }
  }
}

// Build the immutable export snapshot of a span.

///|
fn SpanData::from_span(span : SpanSdk) -> SpanData {
  let attributes : Map[String, AttributeValue] = match span.attributes {
    Some(attributes) => attributes
    None => Map([], capacity=1)
  }
  let events : Array[SpanEvent] = match span.events {
    Some(events) => events
    None => []
  }
  let links : Array[SpanLink] = match span.links {
    Some(links) => links
    None => []
  }
  {
    name: span.name,
    span_context: span.context,
    parent_span_id: span.parent_span_id,
    kind: span.kind,
    start_time_unix_nano: span.start_time_unix_nano,
    end_time_unix_nano: span.end_time_unix_nano,
    attributes,
    events,
    links,
    dropped_attributes_count: span.dropped_attributes,
    dropped_events_count: span.dropped_events,
    dropped_links_count: span.dropped_links,
    status: span.status,
    status_description: span.status_description,
    resource: span.resource,
    scope_name: span.scope_name,
    scope_version: span.scope_version,
  }
}

// End the span, notifying the processors if the span is recording.
// Calling `end` more than once is a no-op.

///|
pub fn SpanSdk::end(self : SpanSdk, end_time_unix_nano? : Int64) -> Unit {
  if self.ended {
    return
  }
  self.ended = true
  let mut clock_millis : UInt64 = 0
  let read_clock = match end_time_unix_nano {
    Some(value) => {
      self.end_time_unix_nano = value
      false
    }
    None => {
      clock_millis = @env.now()
      self.end_time_unix_nano = (clock_millis * 1000000).reinterpret_as_int64()
      true
    }
  }
  if self.recording && self.processors.length() > 0 {
    if read_clock {
      end_clock_millis.val = clock_millis
      end_clock_fresh.val = true
    }
    let data = SpanData::from_span(self)
    for processor in self.processors {
      processor.on_end(data)
    }
    if read_clock {
      end_clock_fresh.val = false
    }
  }
}

///|
pub extend AttributeValue with Eq::{not_equal, equal}

///|
pub extend AttributeValue with @debug.Debug::{to_repr}
