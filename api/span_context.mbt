// SpanContext represents immutable identifier for a Span
pub struct SpanContext {
  trace_id : Array[Int]
  span_id : Array[Int]
  trace_flags : Int
  is_valid : Bool
}

// Create an invalid SpanContext
pub fn invalid_span_context() -> SpanContext {
  { trace_id: Array::make(16, 0), span_id: Array::make(8, 0), trace_flags: 0, is_valid: false }
}

// Create a valid SpanContext with given IDs
pub fn span_context(trace_id : Array[Int], span_id : Array[Int], trace_flags : Int) -> SpanContext {
  let is_valid = trace_id.length() == 16 && span_id.length() == 8 && !is_zero(trace_id) && !is_zero(span_id)
  { trace_id: trace_id, span_id: span_id, trace_flags: trace_flags, is_valid: is_valid }
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
  (self.trace_flags & 1) != 0
}

// Helper: check if byte array is all zeros
pub fn is_zero(bytes : Array[Int]) -> Bool {
  let len = bytes.length()
  let mut i = 0
  while i < len {
    if bytes[i] != 0 {
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

fn nibble_to_hex_char(val : Int) -> Char {
  if val >= 0 && val < 10 {
    (val + 48).unsafe_to_char()
  } else if val >= 10 && val < 16 {
    (val + 87).unsafe_to_char()
  } else {
    '0'
  }
}

// Helper: convert bytes to hex string
pub fn bytes_to_hex(bytes : Array[Int]) -> String {
  let len = bytes.length()
  let sb = StringBuilder(size_hint = len * 4)
  let mut i = 0
  while i < len {
    let b = bytes[i]
    sb.write_char(nibble_to_hex_char(b >> 4))
    sb.write_char(nibble_to_hex_char(b & 0x0F))
    i = i + 1
  }
  sb.to_string()
}

// Helper: convert byte value to hex character
pub fn byte_to_hex_char(val : Int) -> String {
  if val >= 0 && val < 16 {
    hex_digits[val]
  } else {
    "0"
  }
}
