// The SDK Span implementation and the immutable SpanData snapshot that is
// handed to span processors and exporters.

// Value of a span attribute. `StringArrayValue` covers string arrays, which
// is the only array type required by the OTLP MVP.
pub(all) enum AttributeValue {
  StringValue(String)
  BoolValue(Bool)
  IntValue(Int64)
  DoubleValue(Double)
  StringArrayValue(Array[String])
} derive(Eq, @debug.Debug)

// A timestamped event attached to a span.
pub(all) struct SpanEvent {
  name : String
  time_unix_nano : Int64
  attributes : Map[String, AttributeValue]
}

// Immutable snapshot of a span, produced when the span ends.
pub(all) struct SpanData {
  name : String
  span_context : @api.SpanContext
  parent_span_id : Array[Int]
  kind : @api.SpanKind
  start_time_unix_nano : Int64
  end_time_unix_nano : Int64
  attributes : Map[String, AttributeValue]
  events : Array[SpanEvent]
  status : @api.StatusCode
  status_description : String
  resource : Map[String, AttributeValue]
  scope_name : String
  scope_version : String
}

// Current wall-clock time in nanoseconds since the Unix epoch.
fn unix_nano_now() -> Int64 {
  (@env.now() * 1000000).reinterpret_as_int64()
}

// A recording span. Non-recording spans (sampler decision DROP) discard
// attributes and events and are never exported.
pub struct SpanSdk {
  mut name : String
  context : @api.SpanContext
  parent_span_id : Array[Int]
  kind : @api.SpanKind
  start_time_unix_nano : Int64
  mut end_time_unix_nano : Int64
  mut ended : Bool
  recording : Bool
  attributes : Map[String, AttributeValue]
  events : Array[SpanEvent]
  mut status : @api.StatusCode
  mut status_description : String
  processors : Array[&SpanProcessor]
  resource : Map[String, AttributeValue]
  scope_name : String
  scope_version : String
}

fn create_span(
  name : String,
  context : @api.SpanContext,
  parent_span_id : Array[Int],
  kind : @api.SpanKind,
  start_time_unix_nano : Int64,
  recording : Bool,
  processors : Array[&SpanProcessor],
  resource : Map[String, AttributeValue],
  scope_name : String,
  scope_version : String
) -> SpanSdk {
  {
    name,
    context,
    parent_span_id,
    kind,
    start_time_unix_nano,
    end_time_unix_nano: 0,
    ended: false,
    recording,
    attributes: Map([]),
    events: [],
    status: @api.StatusCode::Unset,
    status_description: "",
    processors,
    resource,
    scope_name,
    scope_version,
  }
}

// The SpanContext of this span.
pub fn SpanSdk::context(self : SpanSdk) -> @api.SpanContext {
  self.context
}

// Whether the span records attributes and events.
pub fn SpanSdk::is_recording(self : SpanSdk) -> Bool {
  self.recording
}

// Whether the span has already ended.
pub fn SpanSdk::is_ended(self : SpanSdk) -> Bool {
  self.ended
}

// The span kind.
pub fn SpanSdk::kind(self : SpanSdk) -> @api.SpanKind {
  self.kind
}

// The span name.
pub fn SpanSdk::name(self : SpanSdk) -> String {
  self.name
}

// The span start time in nanoseconds since the Unix epoch.
pub fn SpanSdk::start_time_unix_nano(self : SpanSdk) -> Int64 {
  self.start_time_unix_nano
}

// The span end time in nanoseconds since the Unix epoch (0 while running).
pub fn SpanSdk::end_time_unix_nano(self : SpanSdk) -> Int64 {
  self.end_time_unix_nano
}

// The parent span ID, or an empty array for root spans.
pub fn SpanSdk::parent_span_id(self : SpanSdk) -> Array[Int] {
  self.parent_span_id.copy()
}

// The recorded attributes (empty for non-recording spans).
pub fn SpanSdk::attributes(self : SpanSdk) -> Map[String, AttributeValue] {
  self.attributes
}

// The recorded events (empty for non-recording spans).
pub fn SpanSdk::events(self : SpanSdk) -> Array[SpanEvent] {
  self.events
}

// The current span status.
pub fn SpanSdk::status(self : SpanSdk) -> @api.StatusCode {
  self.status
}

// The human-readable description associated with the status.
pub fn SpanSdk::status_description(self : SpanSdk) -> String {
  self.status_description
}

// Update the span name. No-op for non-recording or ended spans.
pub fn SpanSdk::update_name(self : SpanSdk, name : String) -> Unit {
  if self.recording && !self.ended {
    self.name = name
  }
}

// Set a single attribute. No-op for non-recording or ended spans.
pub fn SpanSdk::set_attribute(
  self : SpanSdk,
  key : String,
  value : AttributeValue
) -> Unit {
  if self.recording && !self.ended {
    self.attributes.set(key, value)
  }
}

// Set multiple attributes. No-op for non-recording or ended spans.
pub fn SpanSdk::set_attributes(
  self : SpanSdk,
  attributes : Map[String, AttributeValue]
) -> Unit {
  if self.recording && !self.ended {
    attributes.each(fn(key, value) { self.attributes.set(key, value) })
  }
}

// Add an event to the span. No-op for non-recording or ended spans.
pub fn SpanSdk::add_event(
  self : SpanSdk,
  name : String,
  attributes? : Map[String, AttributeValue],
  time_unix_nano? : Int64
) -> Unit {
  if self.recording && !self.ended {
    let timestamp = match time_unix_nano {
      Some(value) => value
      None => unix_nano_now()
    }
    let event_attributes = match attributes {
      Some(map) => map
      None => Map([])
    }
    self.events.push({ name, time_unix_nano: timestamp, attributes: event_attributes })
  }
}

// Record an exception as an `exception` event, following the OpenTelemetry
// semantic conventions (`exception.type` / `exception.message`).
// No-op for non-recording or ended spans.
pub fn SpanSdk::record_exception(
  self : SpanSdk,
  error : Error,
  exception_type? : String,
  time_unix_nano? : Int64
) -> Unit {
  if self.recording && !self.ended {
    let message = @debug.to_string(error)
    let attributes = Map([])
    let type_name = match exception_type {
      Some(value) => value
      None => error.to_string()
    }
    attributes.set(EXCEPTION_TYPE, StringValue(type_name))
    attributes.set(EXCEPTION_MESSAGE, StringValue(message))
    self.add_event(
      "exception",
      attributes=attributes,
      time_unix_nano?=time_unix_nano,
    )
  }
}

// Set the span status. No-op for non-recording or ended spans.
//
// Status follows the OpenTelemetry total order `Ok > Error > Unset`: `Ok` is
// final, an `Unset` attempt is ignored, and a description is only recorded
// together with `Error`.
pub fn SpanSdk::set_status(
  self : SpanSdk,
  status : @api.StatusCode,
  description? : String
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
fn SpanData::from_span(span : SpanSdk) -> SpanData {
  {
    name: span.name,
    span_context: span.context,
    parent_span_id: span.parent_span_id,
    kind: span.kind,
    start_time_unix_nano: span.start_time_unix_nano,
    end_time_unix_nano: span.end_time_unix_nano,
    attributes: span.attributes,
    events: span.events,
    status: span.status,
    status_description: span.status_description,
    resource: span.resource,
    scope_name: span.scope_name,
    scope_version: span.scope_version,
  }
}

// End the span, notifying the processors if the span is recording.
// Calling `end` more than once is a no-op.
pub fn SpanSdk::end(self : SpanSdk, end_time_unix_nano? : Int64) -> Unit {
  if self.ended {
    return
  }
  self.ended = true
  self.end_time_unix_nano = match end_time_unix_nano {
    Some(value) => value
    None => unix_nano_now()
  }
  if self.recording && self.processors.length() > 0 {
    let data = SpanData::from_span(self)
    for processor in self.processors {
      processor.on_end(data)
    }
  }
}

pub extend AttributeValue with Eq::{not_equal, equal}
pub extend AttributeValue with @debug.Debug::{to_repr}
