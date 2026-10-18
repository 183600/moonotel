// SpanContext represents immutable identifier for a Span
pub struct SpanContext {
  trace_id : Array[Int]
  span_id : Array[Int]
  trace_flags : Int
  tracestate : String
  is_valid : Bool
  is_remote : Bool
}

// Create an invalid SpanContext
let invalid_context : SpanContext = {
  trace_id: Array::make(16, 0),
  span_id: Array::make(8, 0),
  trace_flags: 0,
  tracestate: "",
  is_valid: false,
  is_remote: false,
}

pub fn invalid_span_context() -> SpanContext {
  invalid_context
}

// Create a valid SpanContext with given IDs. `tracestate` is the raw W3C
// `tracestate` header value associated with the context ("" when absent).
// `is_remote` must be `true` for contexts received through a propagator.
pub fn span_context(
  trace_id : Array[Int],
  span_id : Array[Int],
  trace_flags : Int,
  tracestate? : String,
  is_remote? : Bool
) -> SpanContext {
  let is_valid = trace_id.length() == 16 && span_id.length() == 8 && !is_zero(trace_id) && !is_zero(span_id)
  {
    trace_id: trace_id,
    span_id: span_id,
    trace_flags: trace_flags,
    tracestate: tracestate.unwrap_or(""),
    is_valid: is_valid,
    is_remote: is_remote.unwrap_or(false),
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

// Whether this context was received from a remote parent (through a
// propagator). All-zero contexts and contexts created locally return `false`.
pub fn SpanContext::is_remote(self : SpanContext) -> Bool {
  self.is_remote
}

// Derive a copy of this context with the given `is_remote` flag.
pub fn SpanContext::with_remote(
  self : SpanContext,
  is_remote : Bool
) -> SpanContext {
  { ..self, is_remote }
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

// ASCII code unit of every hex digit 0-9a-f, indexed by the digit value.
let hex_ascii : FixedArray[Byte] = build_hex_ascii()

fn build_hex_ascii() -> FixedArray[Byte] {
  let table : FixedArray[Byte] = FixedArray::make(16, b'0')
  let mut i = 0
  while i < 16 {
    table.unsafe_set(
      i,
      if i < 10 { (i + 48).to_byte() } else { (i + 87).to_byte() },
    )
    i = i + 1
  }
  table
}

// UTF-16LE code unit pairs for every byte value: entry `b` holds the two hex
// characters of `b` packed into one 32-bit word (low byte first).
let hex_pairs : FixedArray[UInt] = build_hex_pairs()

fn build_hex_pairs() -> FixedArray[UInt] {
  let table : FixedArray[UInt] = FixedArray::make(256, 0U)
  let mut b = 0
  while b < 256 {
    let hi = b >> 4
    let lo = b & 0x0F
    let hi_char = if hi < 10 { hi + 48 } else { hi + 87 }
    let lo_char = if lo < 10 { lo + 48 } else { lo + 87 }
    table.unsafe_set(b, (hi_char | (lo_char << 16)).reinterpret_as_uint())
    b = b + 1
  }
  table
}

// Reverse table: the 0-15 value of each ASCII hex digit, -1 for every other
// code unit below 128.
let hex_value : FixedArray[Int] = build_hex_value()

fn build_hex_value() -> FixedArray[Int] {
  let table : FixedArray[Int] = FixedArray::make(128, -1)
  let mut i = 0
  while i < 10 {
    table.unsafe_set(48 + i, i)
    i = i + 1
  }
  let mut j = 0
  while j < 6 {
    table.unsafe_set(65 + j, 10 + j)
    table.unsafe_set(97 + j, 10 + j)
    j = j + 1
  }
  table
}

// Helper: convert bytes to hex string
pub fn bytes_to_hex(bytes : Array[Int]) -> String {
  let len = bytes.length()
  // A String stores UTF-16 code units, so each of the `len * 2` hex
  // characters needs two bytes (low byte first, high byte zero for ASCII).
  let out = FixedArray::make(len * 4, b'\x00')
  let mut i = 0
  while i + 2 <= len {
    let b0 = bytes.unsafe_get(i)
    let b1 = bytes.unsafe_get(i + 1)
    let pos = i * 4
    if b0 >= 0 && b0 < 256 && b1 >= 0 && b1 < 256 {
      let word = hex_pairs.unsafe_get(b0).to_uint64() |
        (hex_pairs.unsafe_get(b1).to_uint64() << 32)
      out.unsafe_write_uint64_le(pos, word)
    } else {
      let hi0 = b0 >> 4
      out.unsafe_set(
        pos,
        if hi0 >= 0 && hi0 < 16 { hex_ascii.unsafe_get(hi0) } else { b'0' },
      )
      out.unsafe_set(pos + 2, hex_ascii.unsafe_get(b0 & 0x0F))
      let hi1 = b1 >> 4
      out.unsafe_set(
        pos + 4,
        if hi1 >= 0 && hi1 < 16 { hex_ascii.unsafe_get(hi1) } else { b'0' },
      )
      out.unsafe_set(pos + 6, hex_ascii.unsafe_get(b1 & 0x0F))
    }
    i = i + 2
  }
  while i < len {
    let b = bytes.unsafe_get(i)
    let pos = i * 4
    if b >= 0 && b < 256 {
      out.unsafe_write_uint32_le(pos, hex_pairs.unsafe_get(b))
    } else {
      let hi = b >> 4
      out.unsafe_set(
        pos,
        if hi >= 0 && hi < 16 { hex_ascii.unsafe_get(hi) } else { b'0' },
      )
      out.unsafe_set(pos + 2, hex_ascii.unsafe_get(b & 0x0F))
    }
    i = i + 1
  }
  out.unsafe_reinterpret_as_bytes().to_unchecked_string()
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
  if code >= 0 && code < 128 {
    hex_value.unsafe_get(code)
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
  // Every element is written before the function returns.
  let out : Array[Int] = Array::unsafe_make_uninit(len / 2)
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
  let trace_id = match bytes_from_hex(trace_id_hex) {
    Some(bytes) => bytes
    None => return invalid_span_context()
  }
  let span_id = match bytes_from_hex(span_id_hex) {
    Some(bytes) => bytes
    None => return invalid_span_context()
  }
  // Decoding even-length hex already guarantees the 16/8-byte lengths; only
  // the all-zero rule of `span_context` remains to be checked.
  if is_zero(trace_id) || is_zero(span_id) {
    return invalid_span_context()
  }
  {
    trace_id,
    span_id,
    trace_flags,
    tracestate: "",
    is_valid: true,
    is_remote: false,
  }
}
