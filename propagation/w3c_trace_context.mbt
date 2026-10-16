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

// Value of a hex digit, or -1 when the character is not a hex digit.
fn hex_digit_value(c : Char) -> Int {
  let code = c.to_int()
  if code >= 48 && code <= 57 {
    code - 48
  } else if code >= 97 && code <= 102 {
    code - 87
  } else if code >= 65 && code <= 70 {
    code - 55
  } else {
    -1
  }
}

// Decode `byte_count` hex byte pairs starting at `start`, validating as it
// goes. Returns None when any character is not a hex digit.
fn decode_hex(value : String, start : Int, byte_count : Int) -> Array[Int]? {
  let out : Array[Int] = Array(capacity=byte_count)
  let mut i = 0
  while i < byte_count {
    let hi = hex_digit_value(value.unsafe_get(start + i * 2).unsafe_to_char())
    let lo = hex_digit_value(value.unsafe_get(start + i * 2 + 1).unsafe_to_char())
    if hi < 0 || lo < 0 {
      return None
    }
    out.push(hi * 16 + lo)
    i = i + 1
  }
  Some(out)
}

fn nibble_to_hex_char(value : Int) -> Char {
  if value >= 0 && value < 10 {
    (value + 48).unsafe_to_char()
  } else if value >= 10 && value < 16 {
    (value + 87).unsafe_to_char()
  } else {
    '0'
  }
}

fn write_hex(sb : StringBuilder, bytes : Array[Int]) -> Unit {
  for byte in bytes {
    sb.write_char(nibble_to_hex_char(byte >> 4))
    sb.write_char(nibble_to_hex_char(byte & 0x0F))
  }
}

// Format a valid SpanContext as a `traceparent` header value (version 00).
// An invalid SpanContext yields an empty string.
pub fn format_traceparent(sc : @api.SpanContext) -> String {
  if !sc.is_valid() {
    return ""
  }
  let flags = sc.trace_flags() & 0xFF
  let sb = StringBuilder(size_hint=55)
  sb.write_string("00-")
  write_hex(sb, sc.trace_id())
  sb.write_char('-')
  write_hex(sb, sc.span_id())
  sb.write_char('-')
  sb.write_char(nibble_to_hex_char(flags >> 4))
  sb.write_char(nibble_to_hex_char(flags & 0x0F))
  sb.to_string()
}

// Parse a `traceparent` header value into a SpanContext.
// Returns None when the value is malformed, uses `ff` as version, contains
// all-zero IDs, or otherwise violates the specification.
pub fn parse_traceparent(value : String) -> @api.SpanContext? {
  let len = value.length()
  // The shortest well-formed value is `00-` + 32 + `-` + 16 + `-` + 2 = 55
  // characters, so anything shorter cannot parse.
  if len < 55 {
    return None
  }
  let mut dash0 = -1
  let mut dash1 = -1
  let mut dash2 = -1
  let mut extra_dashes = false
  let mut i = 0
  while i < len {
    if value.unsafe_get(i).unsafe_to_char() == '-' {
      if dash0 < 0 {
        dash0 = i
      } else if dash1 < 0 {
        dash1 = i
      } else if dash2 < 0 {
        dash2 = i
      } else {
        // A fourth dash marks an extra field; no later position is needed.
        extra_dashes = true
        break
      }
    }
    i = i + 1
  }
  if dash2 < 0 || dash0 != 2 {
    return None
  }
  let version_hi = value.unsafe_get(0).unsafe_to_char()
  let version_lo = value.unsafe_get(1).unsafe_to_char()
  if !is_hex_digit(version_hi) || !is_hex_digit(version_lo) {
    return None
  }
  if (version_hi == 'f' || version_hi == 'F') &&
    (version_lo == 'f' || version_lo == 'F') {
    // `ff` is a reserved invalid version.
    return None
  }
  if dash1 - dash0 != 33 || dash2 - dash1 != 17 {
    return None
  }
  let flags_start = dash2 + 1
  if flags_start + 2 > len {
    return None
  }
  let flags_hi = hex_digit_value(value.unsafe_get(flags_start).unsafe_to_char())
  let flags_lo = hex_digit_value(
    value.unsafe_get(flags_start + 1).unsafe_to_char(),
  )
  if flags_hi < 0 || flags_lo < 0 {
    return None
  }
  if flags_start + 2 < len &&
    value.unsafe_get(flags_start + 2).unsafe_to_char() != '-' {
    return None
  }
  if version_hi == '0' && version_lo == '0' && extra_dashes {
    // Version 00 does not allow additional fields.
    return None
  }
  let trace_id = match decode_hex(value, dash0 + 1, 16) {
    Some(bytes) => bytes
    None => return None
  }
  let span_id = match decode_hex(value, dash1 + 1, 8) {
    Some(bytes) => bytes
    None => return None
  }
  let flags = flags_hi * 16 + flags_lo
  let sc = @api.span_context(trace_id, span_id, flags & @api.TRACE_FLAGS_SAMPLED)
  if sc.is_valid() {
    Some(sc)
  } else {
    None
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
