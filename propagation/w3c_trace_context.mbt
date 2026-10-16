// W3C Trace Context (Level 2) propagator for the `traceparent` and
// `tracestate` headers.
//
// `traceparent` layout: `version-trace-id-parent-id-trace-flags`
//   - version: 2 hex chars, `ff` is invalid
//   - trace-id: 32 hex chars, all-zero is invalid
//   - parent-id: 16 hex chars, all-zero is invalid
//   - trace-flags: 2 hex chars, only the sampled bit is kept
//
// Parsing is lenient about hex case and about extra fields for versions
// greater than `00`, as recommended by the specification.

// Name of the `traceparent` header
pub fn traceparent_header_name() -> String {
  "traceparent"
}

// Name of the `tracestate` header
pub fn tracestate_header_name() -> String {
  "tracestate"
}

fn is_hex_digit(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

fn is_hex_string(value : String, expected_length : Int) -> Bool {
  let chars = value.to_array()
  if chars.length() != expected_length {
    return false
  }
  for c in chars {
    if !is_hex_digit(c) {
      return false
    }
  }
  true
}

// Format a valid SpanContext as a `traceparent` header value (version 00).
// An invalid SpanContext yields an empty string.
pub fn format_traceparent(sc : @api.SpanContext) -> String {
  if !sc.is_valid() {
    return ""
  }
  let flags = sc.trace_flags() & 0xFF
  "00-" +
  sc.trace_id_hex() +
  "-" +
  sc.span_id_hex() +
  "-" +
  @api.bytes_to_hex([flags])
}

// Parse a `traceparent` header value into a SpanContext.
// Returns None when the value is malformed, uses `ff` as version, contains
// all-zero IDs, or otherwise violates the specification.
pub fn parse_traceparent(value : String) -> @api.SpanContext? {
  let parts = value.split("-").collect()
  let count = parts.length()
  if count < 4 {
    return None
  }
  let version = parts[0].to_string()
  if !is_hex_string(version, 2) || version.to_lower() == "ff" {
    return None
  }
  if version == "00" && count != 4 {
    // Version 00 does not allow additional fields.
    return None
  }
  let trace_id_hex = parts[1].to_string()
  let span_id_hex = parts[2].to_string()
  let flags_hex = parts[3].to_string()
  if !is_hex_string(trace_id_hex, 32) ||
    !is_hex_string(span_id_hex, 16) ||
    !is_hex_string(flags_hex, 2) {
    return None
  }
  match (@api.bytes_from_hex(trace_id_hex), @api.bytes_from_hex(span_id_hex), @api.bytes_from_hex(flags_hex)) {
    (Some(trace_id), Some(span_id), Some(flags)) => {
      let sc = @api.span_context(trace_id, span_id, flags[0] & @api.TRACE_FLAGS_SAMPLED)
      if sc.is_valid() {
        Some(sc)
      } else {
        None
      }
    }
    _ => None
  }
}

// Inject a SpanContext into the carrier as a `traceparent` header.
// Does nothing when the SpanContext is invalid.
pub fn inject(sc : @api.SpanContext, carrier : TextMapCarrier) -> Unit {
  if sc.is_valid() {
    carrier.set(traceparent_header_name(), format_traceparent(sc))
  }
}

// Extract a SpanContext from the carrier's `traceparent` header.
pub fn extract(carrier : TextMapCarrier) -> @api.SpanContext? {
  match carrier.get(traceparent_header_name()) {
    Some(value) => parse_traceparent(value)
    None => None
  }
}

// Inject both `traceparent` and (when non-empty) `tracestate`.
pub fn inject_with_tracestate(
  sc : @api.SpanContext,
  tracestate : String?,
  carrier : TextMapCarrier
) -> Unit {
  inject(sc, carrier)
  match tracestate {
    Some(state) =>
      if !state.is_empty() {
        carrier.set(tracestate_header_name(), state)
      }
    None => ()
  }
}

// Extract the raw `tracestate` header value, if present.
// The value is passed through unchanged.
pub fn extract_tracestate(carrier : TextMapCarrier) -> String? {
  carrier.get(tracestate_header_name())
}
