// SpanContext represents immutable identifier for a Span
pub struct SpanContext {
  trace_id : Array[Int]
  span_id : Array[Int]
  trace_flags : Int
  tracestate : String
  is_valid : Bool
}

// Create an invalid SpanContext
let invalid_context : SpanContext = {
  trace_id: Array::make(16, 0),
  span_id: Array::make(8, 0),
  trace_flags: 0,
  tracestate: "",
  is_valid: false,
}

pub fn invalid_span_context() -> SpanContext {
  invalid_context
}

// Create a valid SpanContext with given IDs. `tracestate` is the raw W3C
// `tracestate` header value associated with the context ("" when absent).
pub fn span_context(
  trace_id : Array[Int],
  span_id : Array[Int],
  trace_flags : Int,
  tracestate? : String
) -> SpanContext {
  let is_valid = trace_id.length() == 16 && span_id.length() == 8 && !is_zero(trace_id) && !is_zero(span_id)
  {
    trace_id: trace_id,
    span_id: span_id,
    trace_flags: trace_flags,
    tracestate: tracestate.unwrap_or(""),
    is_valid: is_valid,
  }
}

// The W3C `tracestate` associated with this context ("" when absent).
pub fn SpanContext::tracestate(self : SpanContext) -> String {
  self.tracestate
}

// Derive a copy of this context carrying the given `tracestate` value.
pub fn SpanContext::with_tracestate(
  self : SpanContext,
  tracestate : String
) -> SpanContext {
  { ..self, tracestate }
}

// Check if SpanContext is valid
pub fn SpanContext::is_valid(self : SpanContext) -> Bool {
  self.is_valid
}

// Get trace ID as hex string
pub fn SpanContext::trace_id_hex(self : SpanContext) -> String {
  bytes_to_hex(self.trace_id)
}

// Get span ID as hex string
pub fn SpanContext::span_id_hex(self : SpanContext) -> String {
  bytes_to_hex(self.span_id)
}

// Check if trace flags indicate sampled
pub fn SpanContext::is_sampled(self : SpanContext) -> Bool {
  self.is_valid && (self.trace_flags & 1) != 0
}

// Helper: check if byte array is all zeros
pub fn is_zero(bytes : Array[Int]) -> Bool {
  let len = bytes.length()
  let mut i = 0
  while i < len {
    if bytes.unsafe_get(i) != 0 {
      return false
    }
    i = i + 1
  }
  true
}

let hex_digits : Array[String] = [
  "0", "1", "2", "3", "4", "5", "6", "7",
  "8", "9", "a", "b", "c", "d", "e", "f",
]

fn nibble_to_hex_byte(val : Int) -> Byte {
  if val >= 0 && val < 10 {
    (val + 48).to_byte()
  } else if val >= 10 && val < 16 {
    (val + 87).to_byte()
  } else {
    b'0'
  }
}

// Helper: convert bytes to hex string
pub fn bytes_to_hex(bytes : Array[Int]) -> String {
  let len = bytes.length()
  // A String stores UTF-16 code units, so each of the `len * 2` hex
  // characters needs two bytes (low byte first, high byte zero for ASCII).
  let out = FixedArray::make(len * 4, b'\x00')
  let mut i = 0
  while i < len {
    let b = bytes.unsafe_get(i)
    out.unsafe_set(i * 4, nibble_to_hex_byte(b >> 4))
    out.unsafe_set(i * 4 + 2, nibble_to_hex_byte(b & 0x0F))
    i = i + 1
  }
  Bytes::from_array(out[:]).to_unchecked_string()
}

// Helper: convert byte value to hex character
pub fn byte_to_hex_char(val : Int) -> String {
  if val >= 0 && val < 16 {
    hex_digits[val]
  } else {
    "0"
  }
}

// Trace flag bit indicating that the trace is sampled
pub const TRACE_FLAGS_SAMPLED : Int = 1

// Get the raw trace flags
pub fn SpanContext::trace_flags(self : SpanContext) -> Int {
  self.trace_flags
}

// Get a copy of the trace ID bytes
pub fn SpanContext::trace_id(self : SpanContext) -> Array[Int] {
  self.trace_id.copy()
}

// Get a copy of the span ID bytes
pub fn SpanContext::span_id(self : SpanContext) -> Array[Int] {
  self.span_id.copy()
}

// The trace ID bytes backing this context. The returned array is shared with
// the context and must not be mutated.
pub fn SpanContext::trace_id_view(self : SpanContext) -> Array[Int] {
  self.trace_id
}

// The span ID bytes backing this context. The returned array is shared with
// the context and must not be mutated.
pub fn SpanContext::span_id_view(self : SpanContext) -> Array[Int] {
  self.span_id
}

// Helper: convert a hex character to its 0-15 value, or -1 when the character
// is not a hex digit.
fn hex_char_value(c : Char) -> Int {
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

// Parse a hex string into a byte array; returns None on odd length or invalid chars
pub fn bytes_from_hex(hex : String) -> Array[Int]? {
  let len = hex.length()
  if len % 2 != 0 {
    return None
  }
  let out : Array[Int] = Array::make(len / 2, 0)
  let mut i = 0
  while i < len {
    let hi = hex_char_value(hex.unsafe_get(i).unsafe_to_char())
    let lo = hex_char_value(hex.unsafe_get(i + 1).unsafe_to_char())
    if hi < 0 || lo < 0 {
      return None
    }
    out.unsafe_set(i / 2, hi * 16 + lo)
    i = i + 2
  }
  Some(out)
}

// Build a SpanContext from hex-encoded trace and span IDs
pub fn span_context_from_hex(
  trace_id_hex : String,
  span_id_hex : String,
  trace_flags : Int
) -> SpanContext {
  if trace_id_hex.length() != 32 || span_id_hex.length() != 16 {
    return invalid_span_context()
  }
  match (bytes_from_hex(trace_id_hex), bytes_from_hex(span_id_hex)) {
    (Some(trace_id), Some(span_id)) =>
      if trace_id.length() == 16 && span_id.length() == 8 {
        span_context(trace_id, span_id, trace_flags)
      } else {
        invalid_span_context()
      }
    _ => invalid_span_context()
  }
}
