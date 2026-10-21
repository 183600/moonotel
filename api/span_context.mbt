// SpanContext represents immutable identifier for a Span

///|
pub struct SpanContext {
  trace_id : Array[Int32]
  span_id : Array[Int32]
  trace_flags : Int32
  tracestate : String
  is_valid : Bool
  is_remote : Bool
}

// Create an invalid SpanContext

///|
let invalid_context : SpanContext = {
  trace_id: Array::make(16, 0),
  span_id: Array::make(8, 0),
  trace_flags: 0,
  tracestate: "",
  is_valid: false,
  is_remote: false,
}

// Zero-filled arrays handed out by `trace_id_view`/`span_id_view` for the
// shared `invalid_span_context()` instance, so that mutating a view can never
// corrupt the singleton's own arrays.

///|
let invalid_trace_id_view : Array[Int32] = Array::make(16, 0)

///|
let invalid_span_id_view : Array[Int32] = Array::make(8, 0)

///|
pub fn invalid_span_context() -> SpanContext {
  invalid_context
}

// Create a valid SpanContext with given IDs. `tracestate` is the raw W3C
// `tracestate` header value associated with the context ("" when absent).
// `is_remote` must be `true` for contexts received through a propagator.

///|
pub fn span_context(
  trace_id : Array[Int32],
  span_id : Array[Int32],
  trace_flags : Int32,
  tracestate? : String,
  is_remote? : Bool,
) -> SpanContext {
  let is_valid = trace_id.length() == 16 &&
    span_id.length() == 8 &&
    !is_zero(trace_id) &&
    !is_zero(span_id)
  {
    trace_id,
    span_id,
    trace_flags,
    tracestate: tracestate.unwrap_or(""),
    is_valid,
    is_remote: is_remote.unwrap_or(false),
  }
}

// The W3C `tracestate` associated with this context ("" when absent).

///|
pub fn SpanContext::tracestate(self : SpanContext) -> String {
  self.tracestate
}

// Derive a copy of this context carrying the given `tracestate` value.

///|
pub fn SpanContext::with_tracestate(
  self : SpanContext,
  tracestate : String,
) -> SpanContext {
  { ..self.copy(), tracestate, }
}

// Whether this context was received from a remote parent (through a
// propagator). All-zero contexts and contexts created locally return `false`.

///|
pub fn SpanContext::is_remote(self : SpanContext) -> Bool {
  self.is_remote
}

// Derive a copy of this context with the given `is_remote` flag.

///|
pub fn SpanContext::with_remote(
  self : SpanContext,
  is_remote : Bool,
) -> SpanContext {
  { ..self.copy(), is_remote, }
}

// Check if SpanContext is valid

///|
pub fn SpanContext::is_valid(self : SpanContext) -> Bool {
  self.is_valid
}

// Get trace ID as hex string

///|
pub fn SpanContext::trace_id_hex(self : SpanContext) -> String {
  bytes_to_hex(self.trace_id)
}

// Get span ID as hex string

///|
pub fn SpanContext::span_id_hex(self : SpanContext) -> String {
  bytes_to_hex(self.span_id)
}

// Check if trace flags indicate sampled

///|
pub fn SpanContext::is_sampled(self : SpanContext) -> Bool {
  self.is_valid && (self.trace_flags & 1) != 0
}

// Helper: check if byte array is all zeros

///|
pub fn is_zero(bytes : Array[Int32]) -> Bool {
  let len = bytes.length()
  let mut i = 0
  // Test two elements per iteration.
  while i + 1 < len {
    if (bytes.unsafe_get(i) | bytes.unsafe_get(i + 1)) != 0 {
      return false
    }
    i = i + 2
  }
  i >= len || bytes.unsafe_get(i) == 0
}

///|
let hex_digits : Array[String] = [
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
]

// ASCII code unit of every hex digit 0-9a-f, indexed by the digit value.

///|
let hex_ascii : FixedArray[Byte] = build_hex_ascii()

///|
fn build_hex_ascii() -> FixedArray[Byte] {
  let table : FixedArray[Byte] = FixedArray::make(16, b'0')
  let mut i = 0
  while i < 16 {
    table.unsafe_set(
      i,
      if i < 10 {
        (i + 48).to_byte()
      } else {
        (i + 87).to_byte()
      },
    )
    i = i + 1
  }
  table
}

// UTF-16LE code unit pairs for every byte value: entry `b` holds the two hex
// characters of `b` packed into one 32-bit word (low byte first).

///|
let hex_pairs : FixedArray[UInt32] = build_hex_pairs()

///|
fn build_hex_pairs() -> FixedArray[UInt32] {
  let table : FixedArray[UInt32] = FixedArray::make(256, 0U)
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

///|
let hex_value : FixedArray[Int32] = build_hex_value()

///|
fn build_hex_value() -> FixedArray[Int32] {
  let table : FixedArray[Int32] = FixedArray::make(128, -1)
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

///|
pub fn bytes_to_hex(bytes : Array[Int32]) -> String {
  let len = bytes.length()
  // A String stores UTF-16 code units, so each of the `len * 2` hex
  // characters needs two bytes (low byte first, high byte zero for ASCII).
  let out = FixedArray::make(len * 4, b'\x00')
  let mut i = 0
  while i + 4 <= len {
    let b0 = bytes.unsafe_get(i)
    let b1 = bytes.unsafe_get(i + 1)
    let b2 = bytes.unsafe_get(i + 2)
    let b3 = bytes.unsafe_get(i + 3)
    let pos = i * 4
    if (b0 | b1 | b2 | b3) >= 0 &&
      b0 < 256 &&
      b1 < 256 &&
      b2 < 256 &&
      b3 < 256 {
      let w0 = hex_pairs.unsafe_get(b0).to_uint64() |
        (hex_pairs.unsafe_get(b1).to_uint64() << 32)
      let w1 = hex_pairs.unsafe_get(b2).to_uint64() |
        (hex_pairs.unsafe_get(b3).to_uint64() << 32)
      out.unsafe_write_uint64_le(pos, w0)
      out.unsafe_write_uint64_le(pos + 8, w1)
    } else {
      let hi0 = b0 >> 4
      out.unsafe_set(
        pos,
        if hi0 >= 0 && hi0 < 16 {
          hex_ascii.unsafe_get(hi0)
        } else {
          b'0'
        },
      )
      out.unsafe_set(pos + 2, hex_ascii.unsafe_get(b0 & 0x0F))
      let hi1 = b1 >> 4
      out.unsafe_set(
        pos + 4,
        if hi1 >= 0 && hi1 < 16 {
          hex_ascii.unsafe_get(hi1)
        } else {
          b'0'
        },
      )
      out.unsafe_set(pos + 6, hex_ascii.unsafe_get(b1 & 0x0F))
      let hi2 = b2 >> 4
      out.unsafe_set(
        pos + 8,
        if hi2 >= 0 && hi2 < 16 {
          hex_ascii.unsafe_get(hi2)
        } else {
          b'0'
        },
      )
      out.unsafe_set(pos + 10, hex_ascii.unsafe_get(b2 & 0x0F))
      let hi3 = b3 >> 4
      out.unsafe_set(
        pos + 12,
        if hi3 >= 0 && hi3 < 16 {
          hex_ascii.unsafe_get(hi3)
        } else {
          b'0'
        },
      )
      out.unsafe_set(pos + 14, hex_ascii.unsafe_get(b3 & 0x0F))
    }
    i = i + 4
  }
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
        if hi0 >= 0 && hi0 < 16 {
          hex_ascii.unsafe_get(hi0)
        } else {
          b'0'
        },
      )
      out.unsafe_set(pos + 2, hex_ascii.unsafe_get(b0 & 0x0F))
      let hi1 = b1 >> 4
      out.unsafe_set(
        pos + 4,
        if hi1 >= 0 && hi1 < 16 {
          hex_ascii.unsafe_get(hi1)
        } else {
          b'0'
        },
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
        if hi >= 0 && hi < 16 {
          hex_ascii.unsafe_get(hi)
        } else {
          b'0'
        },
      )
      out.unsafe_set(pos + 2, hex_ascii.unsafe_get(b & 0x0F))
    }
    i = i + 1
  }
  out.unsafe_reinterpret_as_bytes().to_unchecked_string()
}

// Helper: convert byte value to hex character

///|
pub fn byte_to_hex_char(val : Int32) -> String {
  if val >= 0 && val < 16 {
    hex_digits[val]
  } else {
    "0"
  }
}

// Trace flag bit indicating that the trace is sampled

///|
pub const TRACE_FLAGS_SAMPLED : Int32 = 1

// Trace flag bit indicating that the trace ID was generated randomly
// (W3C Trace Context Level 2 random-trace-id flag).

///|
pub const TRACE_FLAGS_RANDOM : Int32 = 2

// Get the raw trace flags

///|
pub fn SpanContext::trace_flags(self : SpanContext) -> Int32 {
  self.trace_flags
}

// Get a copy of the trace ID bytes

///|
pub fn SpanContext::trace_id(self : SpanContext) -> Array[Int32] {
  self.trace_id.copy()
}

// Get a copy of the span ID bytes

///|
pub fn SpanContext::span_id(self : SpanContext) -> Array[Int32] {
  self.span_id.copy()
}

// Deep-copy this context so that mutating either copy's ID arrays cannot
// affect the other.

///|
pub fn SpanContext::copy(self : SpanContext) -> SpanContext {
  { ..self, trace_id: self.trace_id.copy(), span_id: self.span_id.copy() }
}

// The trace ID bytes backing this context. The returned array is shared with
// the context and must not be mutated. The shared `invalid_span_context()`
// instance hands out a dedicated zero-filled array so that its own arrays
// cannot be corrupted through a view.

///|
pub fn SpanContext::trace_id_view(self : SpanContext) -> Array[Int32] {
  if !self.is_valid && physical_equal(self.trace_id, invalid_context.trace_id) {
    invalid_trace_id_view
  } else {
    self.trace_id
  }
}

// The span ID bytes backing this context. The returned array is shared with
// the context and must not be mutated. The shared `invalid_span_context()`
// instance hands out a dedicated zero-filled array so that its own arrays
// cannot be corrupted through a view.

///|
pub fn SpanContext::span_id_view(self : SpanContext) -> Array[Int32] {
  if !self.is_valid && physical_equal(self.span_id, invalid_context.span_id) {
    invalid_span_id_view
  } else {
    self.span_id
  }
}

// Helper: convert a UTF-16 code unit to its 0-15 hex value, or -1 when the
// code unit is not an ASCII hex digit.

///|
fn hex_unit_value(unit : UInt16) -> Int32 {
  if unit < 128 {
    hex_value.unsafe_get(unit.to_int())
  } else {
    -1
  }
}

// Decode one byte per two hex code units of `hex` into `out` (whose length is
// the number of bytes to decode). Invalid digits are accumulated across the
// loop. Returns false on a non-hex code unit.

///|
fn hex_to_bytes(hex : String, out : Array[Int32]) -> Bool {
  let n = out.length()
  let mut bad = 0
  let mut i = 0
  // Process four bytes per iteration.
  while i + 4 <= n {
    let h0 = hex_unit_value(hex.unsafe_get(i * 2))
    let l0 = hex_unit_value(hex.unsafe_get(i * 2 + 1))
    let h1 = hex_unit_value(hex.unsafe_get(i * 2 + 2))
    let l1 = hex_unit_value(hex.unsafe_get(i * 2 + 3))
    let h2 = hex_unit_value(hex.unsafe_get(i * 2 + 4))
    let l2 = hex_unit_value(hex.unsafe_get(i * 2 + 5))
    let h3 = hex_unit_value(hex.unsafe_get(i * 2 + 6))
    let l3 = hex_unit_value(hex.unsafe_get(i * 2 + 7))
    bad = bad | h0 | l0 | h1 | l1 | h2 | l2 | h3 | l3
    out.unsafe_set(i, h0 * 16 + l0)
    out.unsafe_set(i + 1, h1 * 16 + l1)
    out.unsafe_set(i + 2, h2 * 16 + l2)
    out.unsafe_set(i + 3, h3 * 16 + l3)
    i = i + 4
  }
  while i < n {
    let hi = hex_unit_value(hex.unsafe_get(i * 2))
    let lo = hex_unit_value(hex.unsafe_get(i * 2 + 1))
    bad = bad | hi | lo
    out.unsafe_set(i, hi * 16 + lo)
    i = i + 1
  }
  bad >= 0
}

// Like `hex_to_bytes`, but rejects an all-zero result as well. The zero check
// is accumulated over the same pass.

///|
fn hex_to_nonzero_bytes(hex : String, start : Int32, out : Array[Int32]) -> Bool {
  let n = out.length()
  let mut bad = 0
  let mut acc = 0
  let mut i = 0
  // Process four bytes per iteration.
  while i + 4 <= n {
    let h0 = hex_unit_value(hex.unsafe_get(start + i * 2))
    let l0 = hex_unit_value(hex.unsafe_get(start + i * 2 + 1))
    let h1 = hex_unit_value(hex.unsafe_get(start + i * 2 + 2))
    let l1 = hex_unit_value(hex.unsafe_get(start + i * 2 + 3))
    let h2 = hex_unit_value(hex.unsafe_get(start + i * 2 + 4))
    let l2 = hex_unit_value(hex.unsafe_get(start + i * 2 + 5))
    let h3 = hex_unit_value(hex.unsafe_get(start + i * 2 + 6))
    let l3 = hex_unit_value(hex.unsafe_get(start + i * 2 + 7))
    bad = bad | h0 | l0 | h1 | l1 | h2 | l2 | h3 | l3
    let b0 = h0 * 16 + l0
    let b1 = h1 * 16 + l1
    let b2 = h2 * 16 + l2
    let b3 = h3 * 16 + l3
    acc = acc | b0 | b1 | b2 | b3
    out.unsafe_set(i, b0)
    out.unsafe_set(i + 1, b1)
    out.unsafe_set(i + 2, b2)
    out.unsafe_set(i + 3, b3)
    i = i + 4
  }
  while i < n {
    let hi = hex_unit_value(hex.unsafe_get(start + i * 2))
    let lo = hex_unit_value(hex.unsafe_get(start + i * 2 + 1))
    bad = bad | hi | lo
    let byte = hi * 16 + lo
    acc = acc | byte
    out.unsafe_set(i, byte)
    i = i + 1
  }
  bad >= 0 && acc != 0
}

// Parse a hex string into a byte array; returns None on odd length or invalid chars

///|
pub fn bytes_from_hex(hex : String) -> Array[Int32]? {
  let len = hex.length()
  if len % 2 != 0 {
    return None
  }
  // Every element is written before the function returns.
  let out : Array[Int32] = Array::unsafe_make_uninit(len / 2)
  if hex_to_bytes(hex, out) {
    Some(out)
  } else {
    None
  }
}

// Build a SpanContext from hex-encoded trace and span IDs

///|
pub fn span_context_from_hex(
  trace_id_hex : String,
  span_id_hex : String,
  trace_flags : Int32,
) -> SpanContext {
  if trace_id_hex.length() != 32 || span_id_hex.length() != 16 {
    return invalid_span_context()
  }
  // Decoding validates the hex digits, the 16/8-byte lengths and the all-zero
  // rule of `span_context`.
  let trace_id : Array[Int32] = Array::unsafe_make_uninit(16)
  let span_id : Array[Int32] = Array::unsafe_make_uninit(8)
  if !hex_to_nonzero_bytes(trace_id_hex, 0, trace_id) ||
    !hex_to_nonzero_bytes(span_id_hex, 0, span_id) {
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
