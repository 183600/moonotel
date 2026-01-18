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
fn is_zero(bytes : Array[Int]) -> Bool {
  let mut i = 0
  while i < bytes.length() {
    if bytes[i] != 0 {
      return false
    }
    i = i + 1
  }
  true
}

// Helper: convert bytes to hex string
fn bytes_to_hex(bytes : Array[Int]) -> String {
  let hex_chars = "0123456789abcdef"
  let mut result = ""
  let mut i = 0
  while i < bytes.length() {
    let b = bytes[i]
    let high = b >> 4
    let low = b & 0x0F
    result = result + char_from(hex_chars, high)
    result = result + char_from(hex_chars, low)
    i = i + 1
  }
  result
}

// Helper: get char from string at index
fn char_from(s : String, index : Int) -> String {
  let chars = s.to_array()
  let mut result = ""
  let mut i = 0
  while i < chars.length() {
    if i == index {
      result = result + string_from_char(chars[i])
    }
    i = i + 1
  }
  result
}

// Helper: convert char to string
fn string_from_char(c : Char) -> String {
  c.to_string()
}
