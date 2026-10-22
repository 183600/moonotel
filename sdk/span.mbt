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
  resource : ResourceAttributes
  scope_name : String
  scope_version : String
}

// Current wall-clock time in nanoseconds since the Unix epoch.

///|
fn unix_nano_now() -> Int64 {
  (@env.now() * 1000000).reinterpret_as_int64()
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
  // Export snapshot, filled by `end` when the span recorded data and has
  // processors. The collections are moved (not copied) into it, so accessors
  // fall back to this snapshot once the mutable fields are cleared.
  priv mut snapshot : SpanData?
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

// Empty parent span ID shared by root spans. Spans never mutate it and every
// access returns a copy, so one shared instance is safe.

///|
let no_parent_span_id : Array[Int32] = []

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
    snapshot: None,
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
  // added later; invalid links are ignored unless they carry attributes or a
  // non-empty tracestate.
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
  if limit == 0 {
    return ""
  }
  // Walk `limit` characters, keeping a surrogate pair together so the cut
  // never splits one.
  let mut end = 0
  let mut count : Int32 = 0
  while count < limit && end < len {
    let unit = value.unsafe_get(end).to_int()
    if unit >= 0xD800 &&
      unit <= 0xDBFF &&
      end + 1 < len &&
      value.unsafe_get(end + 1).to_int() >= 0xDC00 &&
      value.unsafe_get(end + 1).to_int() <= 0xDFFF {
      end = end + 2
    } else {
      end = end + 1
    }
    count = count + 1
  }
  if end >= len {
    return value
  }
  // Dropping an unpaired trailing high surrogate can expose an unpaired low
  // before it (and vice versa), so keep trimming until the cut no longer ends
  // on half of a surrogate pair. A complete pair at the cut is valid and kept.
  while end > 0 {
    let last = value.unsafe_get(end - 1).to_int()
    if last >= 0xD800 && last <= 0xDBFF {
      // The value ends on a lone high surrogate: drop it instead of keeping
      // half of a pair.
      end = end - 1
    } else if last >= 0xDC00 && last <= 0xDFFF {
      // A trailing low surrogate that is not preceded by its high half is an
      // unpaired surrogate. Dropping it keeps the truncated value valid UTF-16;
      // a complete pair was consumed together by the loop above and is kept.
      let paired = end >= 2 &&
        value.unsafe_get(end - 2).to_int() >= 0xD800 &&
        value.unsafe_get(end - 2).to_int() <= 0xDBFF
      if paired {
        break
      }
      end = end - 1
    } else {
      break
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
  if (count_limit < 0 || total <= count_limit) && value_length_limit < 0 {
    let kept = copy_attribute_map(attributes)
    // The OpenTelemetry data model requires non-empty attribute keys. An empty
    // key is not an attribute, so it is ignored rather than counted as
    // dropped because of a limit.
    kept.remove("")
    return (kept, 0)
  }
  let capacity = if count_limit < 0 || count_limit > total {
    total
  } else {
    count_limit
  }
  let kept : Map[String, AttributeValue] = Map(
    [], capacity=map_capacity_for_entries(capacity),
  )
  let mut dropped = 0
  for key, value in attributes {
    if key == "" {
      // See above: an empty key is not a valid attribute and does not consume
      // the count limit or the dropped-attribute counter.
      continue
    }
    if within_limit(kept.length(), count_limit) {
      kept.set(
        key,
        copy_attribute_value(
          truncate_attribute_value(value, value_length_limit),
        ),
      )
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
  if key == "" {
    // The OpenTelemetry data model requires a non-empty attribute key. Ignore
    // the invalid attribute instead of exporting it or counting it as dropped
    // because of a limit.
    return
  }
  let attributes = self.mutable_attributes()
  if within_limit(attributes.length(), self.limits.attribute_count_limit) {
    attributes.set(
      key,
      copy_attribute_value(
        truncate_attribute_value(
          value,
          self.limits.attribute_value_length_limit,
        ),
      ),
    )
  } else {
    match attributes.get(key) {
      Some(_) =>
        attributes.set(
          key,
          copy_attribute_value(
            truncate_attribute_value(
              value,
              self.limits.attribute_value_length_limit,
            ),
          ),
        )
      None => self.dropped_attributes = self.dropped_attributes + 1
    }
  }
}

// The SpanContext of this span, as a copy: mutating its ID arrays cannot
// change the span or the data it exports.

///|
pub fn SpanSdk::context(self : SpanSdk) -> @api.SpanContext {
  @api.SpanContext::copy(self.context)
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

// The recorded attributes (empty for non-recording spans). The returned map
// is a snapshot: modifying it does not change the span and cannot bypass the
// span limits.

///|
pub fn SpanSdk::attributes(self : SpanSdk) -> Map[String, AttributeValue] {
  match self.attributes {
    Some(attributes) => copy_attribute_map(attributes)
    None =>
      match self.snapshot {
        Some(data) => copy_attribute_map(data.attributes)
        None => Map([], capacity=1)
      }
  }
}

// Copy an event array so that the returned events and their attribute maps
// are independent of the source.

///|
fn copy_events(events : Array[SpanEvent]) -> Array[SpanEvent] {
  let out : Array[SpanEvent] = Array(capacity=events.length())
  for event in events {
    out.push({
      name: event.name,
      time_unix_nano: event.time_unix_nano,
      attributes: copy_attribute_map(event.attributes),
      dropped_attributes_count: event.dropped_attributes_count,
    })
  }
  out
}

// Copy a link array so that the returned links and their attribute maps are
// independent of the source.

///|
fn copy_links(links : Array[SpanLink]) -> Array[SpanLink] {
  let out : Array[SpanLink] = Array(capacity=links.length())
  for link in links {
    out.push({
      span_context: @api.SpanContext::copy(link.span_context),
      attributes: copy_attribute_map(link.attributes),
      dropped_attributes_count: link.dropped_attributes_count,
    })
  }
  out
}

// The recorded events (empty for non-recording spans). The returned array and
// its events are snapshots: modifying them does not change the span.

///|
pub fn SpanSdk::events(self : SpanSdk) -> Array[SpanEvent] {
  match self.events {
    Some(events) => copy_events(events)
    None =>
      match self.snapshot {
        Some(data) => copy_events(data.events)
        None => []
      }
  }
}

// The links of this span. The returned array and its links are snapshots:
// modifying them does not change the span.

///|
pub fn SpanSdk::links(self : SpanSdk) -> Array[SpanLink] {
  match self.links {
    Some(links) => copy_links(links)
    None =>
      match self.snapshot {
        Some(data) => copy_links(data.links)
        None => []
      }
  }
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
// String values are truncated to the configured value length limit. An empty
// key is invalid and is ignored without affecting the drop counters.

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
// `set_attribute`; entries with an empty key are ignored.

///|
pub fn SpanSdk::set_attributes(
  self : SpanSdk,
  attributes : Map[String, AttributeValue],
) -> Unit {
  if self.recording && !self.ended {
    let count = attributes.length()
    if self.attributes is None && count > 0 {
      let limit = self.limits.attribute_count_limit
      let budget = if limit >= 0 && limit < count { limit } else { count }
      if budget > 0 {
        self.attributes = Some(Map([], capacity=map_capacity_for_entries(budget)))
      }
    }
    for key, value in attributes {
      self.set_attribute_limited(key, value)
    }
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
// event. Event attributes with an empty key are ignored.

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

// Add a link to another span. Links whose SpanContext is invalid are ignored
// unless they carry attributes or a non-empty tracestate, as specified by the
// OpenTelemetry specification. No-op for non-recording or ended spans. When
// the link count limit is reached the link is dropped and counted; attributes
// beyond the link attribute count limit are dropped and counted on the link.
// Link attributes with an empty key are ignored.

///|
pub fn SpanSdk::add_link(self : SpanSdk, link : SpanLink) -> Unit {
  if !(self.recording && !self.ended) {
    return
  }
  let (link_attributes, dropped) = limited_attributes(
    link.attributes,
    self.limits.link_attribute_count_limit,
    self.limits.attribute_value_length_limit,
  )
  // Empty attribute keys are not attributes. An invalid link therefore only
  // survives when it carries a real (non-empty-key) attribute or tracestate.
  // Decide this from the supplied attributes, not the limited result: a link
  // attribute count limit of zero removes every attribute but must not make
  // the link itself disappear.
  let mut has_attribute = false
  for key, _ in link.attributes {
    if key != "" {
      has_attribute = true
      break
    }
  }
  let record = has_live_valid_ids(link.span_context) ||
    has_attribute ||
    link.span_context.tracestate() != ""
  if record {
    if !within_limit(self.link_count(), self.limits.link_count_limit) {
      self.dropped_links = self.dropped_links + 1
      return
    }
    self
    .mutable_links()
    .push({
      span_context: @api.SpanContext::copy(link.span_context),
      attributes: link_attributes,
      dropped_attributes_count: dropped,
    })
  }
}

// Record an exception as an `exception` event, following the OpenTelemetry
// semantic conventions (`exception.type` / `exception.message`). Additional
// event attributes may be supplied; they take precedence over the attributes
// derived from the error. No-op for non-recording or ended spans.

///|
pub fn SpanSdk::record_exception(
  self : SpanSdk,
  error : Error,
  exception_type? : String,
  stacktrace? : String,
  attributes? : Map[String, AttributeValue],
  time_unix_nano? : Int64,
) -> Unit {
  if self.recording && !self.ended {
    let message = @debug.to_string(error)
    let type_name = match exception_type {
      Some(value) => value
      None => error.to_string()
    }
    let event_attributes : Map[String, AttributeValue] = Map([
      (EXCEPTION_TYPE, StringValue(type_name)),
      (EXCEPTION_MESSAGE, StringValue(message)),
    ])
    match stacktrace {
      Some(value) =>
        event_attributes.set(EXCEPTION_STACKTRACE, StringValue(value))
      None => ()
    }
    match attributes {
      Some(extra) =>
        for key, value in extra {
          event_attributes.set(key, value)
        }
      None => ()
    }
    self.add_event("exception", attributes=event_attributes, time_unix_nano?)
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

// Copy an attribute value, cloning the payload of array-valued attributes so
// that the snapshot does not share mutable state with the caller.

///|
fn copy_attribute_value(value : AttributeValue) -> AttributeValue {
  match value {
    StringArrayValue(items) => StringArrayValue(items.copy())
    BoolArrayValue(items) => BoolArrayValue(items.copy())
    IntArrayValue(items) => IntArrayValue(items.copy())
    DoubleArrayValue(items) => DoubleArrayValue(items.copy())
    _ => value
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

// Deep-copy an attribute map (keys and string values are immutable, so only
// the map and array-valued payloads need to be copied).

///|
fn copy_attribute_map(
  attributes : Map[String, AttributeValue],
) -> Map[String, AttributeValue] {
  if attributes.length() == 0 {
    return Map([], capacity=1)
  }
  // Copy the map structure, then clone the mutable array-valued payloads;
  // string and numeric values are immutable.
  let out = attributes.copy()
  for key, value in attributes {
    match value {
      StringArrayValue(_) | BoolArrayValue(_) | IntArrayValue(_)
      | DoubleArrayValue(_) => out.set(key, copy_attribute_value(value))
      _ => ()
    }
  }
  out
}

// Return an attribute map that can be shared by an export snapshot. The map
// may be shared as-is when every value is immutable (string, bool, int,
// double); when an array-valued attribute is present the map and its array
// payloads are copied, because the caller may still mutate the array it
// handed to `set_attribute` while the span was recording.

///|
fn snapshot_attribute_map(
  attributes : Map[String, AttributeValue],
) -> Map[String, AttributeValue] {
  for _, value in attributes {
    match value {
      StringArrayValue(_) | BoolArrayValue(_) | IntArrayValue(_)
      | DoubleArrayValue(_) => return copy_attribute_map(attributes)
      _ => ()
    }
  }
  attributes
}

// Replace the array-valued attribute payloads of `events` with copies. The
// array is owned by the span and is not shared, so it is modified in place.

///|
fn snapshot_events(events : Array[SpanEvent]) -> Array[SpanEvent] {
  for i, event in events {
    let attributes = snapshot_attribute_map(event.attributes)
    if !physical_equal(attributes, event.attributes) {
      events[i] = {
        name: event.name,
        time_unix_nano: event.time_unix_nano,
        attributes,
        dropped_attributes_count: event.dropped_attributes_count,
      }
    }
  }
  events
}

// Replace the array-valued attribute payloads of `links` with copies. The
// array is owned by the span and is not shared, so it is modified in place.

///|
fn snapshot_links(links : Array[SpanLink]) -> Array[SpanLink] {
  for i, link in links {
    let attributes = snapshot_attribute_map(link.attributes)
    if !physical_equal(attributes, link.attributes) {
      links[i] = {
        span_context: link.span_context,
        attributes,
        dropped_attributes_count: link.dropped_attributes_count,
      }
    }
  }
  links
}

// Deep-copy a span snapshot, including every collection and ID array. Span
// processors receive one copy each, so a processor that mutates its
// `SpanData` cannot change what a later processor, the span accessors or the
// exporter sees.

///|
fn SpanData::copy(self : SpanData) -> SpanData {
  {
    ..self,
    span_context: @api.SpanContext::copy(self.span_context),
    parent_span_id: self.parent_span_id.copy(),
    attributes: copy_attribute_map(self.attributes),
    events: copy_events(self.events),
    links: copy_links(self.links),
    resource: self.resource.copy(),
  }
}

// Build the immutable export snapshot of a span, moving its attribute, event
// and link collections into the snapshot. The maps and arrays are not shared
// with anything else: the span clears its own references in `end`, and
// callers only ever receive copies. Array-valued attribute payloads are
// cloned first so that mutating an array the caller still holds cannot change
// the snapshot.

///|
fn SpanData::take_from_span(span : SpanSdk) -> SpanData {
  let attributes : Map[String, AttributeValue] = match span.attributes {
    Some(attributes) => snapshot_attribute_map(attributes)
    None => Map([], capacity=1)
  }
  let events : Array[SpanEvent] = match span.events {
    Some(events) => snapshot_events(events)
    None => []
  }
  let links : Array[SpanLink] = match span.links {
    Some(links) => snapshot_links(links)
    None => []
  }
  span.attributes = None
  span.events = None
  span.links = None
  {
    name: span.name,
    span_context: @api.SpanContext::copy(span.context),
    parent_span_id: span.parent_span_id.copy(),
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
    resource: ResourceAttributes::new(span.resource),
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
  match end_time_unix_nano {
    Some(value) => self.end_time_unix_nano = value
    None =>
      self.end_time_unix_nano = (@env.now() * 1000000).reinterpret_as_int64()
  }
  if self.recording {
    let data = SpanData::take_from_span(self)
    // Keep the snapshot reachable so accessors still report the recorded
    // collections after the mutable fields have been cleared. This also
    // applies when no processor is registered: a recording span is readable
    // after it ends even if nothing consumes its export snapshot. Each
    // processor gets its own copy so one processor cannot mutate the snapshot
    // seen by a later processor or by the span accessors.
    self.snapshot = Some(data)
    for processor in self.processors {
      processor.on_end(data.copy())
    }
  }
}

///|
pub extend AttributeValue with Eq::{not_equal, equal}

///|
pub extend AttributeValue with @debug.Debug::{to_repr}
