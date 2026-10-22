// Propagator for the W3C Trace Context `traceparent` and `tracestate`
// headers (based on Level 2, with the trace-flags handling described below).
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

///|
pub fn traceparent_header_name() -> String {
  "traceparent"
}

// Name of the `tracestate` header

///|
pub fn tracestate_header_name() -> String {
  "tracestate"
}

// HTTP optional whitespace. OWS is `SP / HTAB` only (RFC 9110 §5.6.3); CR
// and LF are not whitespace.

///|
fn is_trim_char(c : Char) -> Bool {
  c == ' ' || c == '\t'
}

// Trim HTTP optional whitespace around a value.

///|
fn trim_ows(value : StringView) -> StringView {
  let len = value.length()
  if len == 0 {
    return value
  }
  if !is_trim_char(value.unsafe_get(0).unsafe_to_char()) &&
    !is_trim_char(value.unsafe_get(len - 1).unsafe_to_char()) {
    return value
  }
  let mut start = 0
  let mut end = len
  while start < end && is_trim_char(value.unsafe_get(start).unsafe_to_char()) {
    start = start + 1
  }
  while end > start && is_trim_char(value.unsafe_get(end - 1).unsafe_to_char()) {
    end = end - 1
  }
  value.view(start_offset=start, end_offset=end)
}

// Index of the first occurrence of `needle` at or after `start`, or the view
// length when absent.

///|
fn find_code_unit(view : StringView, needle : UInt16, start : Int32) -> Int32 {
  let len = view.length()
  let mut i = start
  while i < len {
    if view.unsafe_get(i) == needle {
      return i
    }
    i = i + 1
  }
  len
}

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

// Value of a hex digit, or -1 when the character is not a hex digit.

///|
fn hex_digit_value(c : Char) -> Int32 {
  let code = c.to_int()
  if code >= 0 && code < 128 {
    hex_value.unsafe_get(code)
  } else {
    -1
  }
}

// Value of a UTF-16 code unit as a hex digit, or -1 when it is not an ASCII
// hex digit.

///|
fn hex_unit_value(unit : UInt16) -> Int32 {
  if unit < 128 {
    hex_value.unsafe_get(unit.to_int())
  } else {
    -1
  }
}

// Whether every code unit in `[start, start + count)` is a lowercase hex
// digit (`0-9` or `a-f`), as required by the version 00 ABNF (`HEXDIGLC`).

///|
fn has_lowercase_hex(value : String, start : Int32, count : Int32) -> Bool {
  let end = start + count
  let mut i = start
  while i < end {
    let code = value.unsafe_get(i).to_int()
    if code < 0x30 || (code > 0x39 && (code < 0x61 || code > 0x66)) {
      return false
    }
    i = i + 1
  }
  true
}

// Decode `byte_count` hex byte pairs starting at `start`, validating as it
// goes and tracking whether any byte is non-zero. Returns None when any
// character is not a hex digit or when every decoded byte is zero.

///|
fn decode_hex_nonzero(
  value : String,
  start : Int32,
  byte_count : Int32,
) -> Array[Int32]? {
  // Every element is written before `Some` is returned.
  let out : Array[Int32] = Array::unsafe_make_uninit(byte_count)
  // Accumulate both checks across the loop.
  let mut bad = 0
  let mut acc = 0
  let mut i = 0
  // Process four bytes per iteration.
  while i + 4 <= byte_count {
    let h0 = hex_unit_value(value.unsafe_get(start + i * 2))
    let l0 = hex_unit_value(value.unsafe_get(start + i * 2 + 1))
    let h1 = hex_unit_value(value.unsafe_get(start + i * 2 + 2))
    let l1 = hex_unit_value(value.unsafe_get(start + i * 2 + 3))
    let h2 = hex_unit_value(value.unsafe_get(start + i * 2 + 4))
    let l2 = hex_unit_value(value.unsafe_get(start + i * 2 + 5))
    let h3 = hex_unit_value(value.unsafe_get(start + i * 2 + 6))
    let l3 = hex_unit_value(value.unsafe_get(start + i * 2 + 7))
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
  while i < byte_count {
    let hi = hex_unit_value(value.unsafe_get(start + i * 2))
    let lo = hex_unit_value(value.unsafe_get(start + i * 2 + 1))
    bad = bad | hi | lo
    let byte = hi * 16 + lo
    acc = acc | byte
    out.unsafe_set(i, byte)
    i = i + 1
  }
  if bad < 0 || acc == 0 {
    return None
  }
  Some(out)
}

///|
fn nibble_to_hex_byte(value : Int32) -> Byte {
  if value >= 0 && value < 16 {
    hex_ascii.unsafe_get(value)
  } else {
    b'0'
  }
}

// Write `byte_count` bytes as hex characters into `out` starting at character
// index `start`. Each character occupies a UTF-16LE code unit (two bytes, low
// byte first); the high bytes are left zero by the caller's buffer.

///|
fn write_hex(
  out : FixedArray[Byte],
  start : Int32,
  bytes : Array[Int32],
  byte_count : Int32,
) -> Unit {
  let mut i = 0
  while i + 4 <= byte_count {
    let b0 = bytes.unsafe_get(i)
    let b1 = bytes.unsafe_get(i + 1)
    let b2 = bytes.unsafe_get(i + 2)
    let b3 = bytes.unsafe_get(i + 3)
    let pos = (start + i * 2) * 2
    if (b0 | b1 | b2 | b3) >= 0 &&
      b0 < 256 &&
      b1 < 256 &&
      b2 < 256 &&
      b3 < 256 {
      out.unsafe_write_uint64_le(
        pos,
        hex_pairs.unsafe_get(b0).to_uint64() |
        (hex_pairs.unsafe_get(b1).to_uint64() << 32),
      )
      out.unsafe_write_uint64_le(
        pos + 8,
        hex_pairs.unsafe_get(b2).to_uint64() |
        (hex_pairs.unsafe_get(b3).to_uint64() << 32),
      )
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
  while i + 2 <= byte_count {
    let b0 = bytes.unsafe_get(i)
    let b1 = bytes.unsafe_get(i + 1)
    let pos = (start + i * 2) * 2
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
  while i < byte_count {
    let b = bytes.unsafe_get(i)
    let pos = (start + i * 2) * 2
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
}

// Known `trace-flags` bits: sampled (`0x01`) and random-trace-id (`0x02`).
// Every other bit is reserved and must be set to zero (W3C Trace Context
// "Other Flags"), while the random bit must be preserved on continuation.

///|
const TRACE_FLAGS_KNOWN : Int32 = 0x03

// Whether the first `byte_count` elements of `bytes` serialize to at least one
// nonzero byte. Values outside 0..255 are serialized like `bytes_to_hex` (the
// high nibble becomes "0" and the low nibble is kept), so they must not be
// mistaken for a nonzero wire byte.

///|
fn has_nonzero_serialized_byte(
  bytes : Array[Int32],
  byte_count : Int32,
) -> Bool {
  let mut i = 0
  while i < byte_count {
    let value = bytes.unsafe_get(i)
    let serialized = if value >= 0 && value < 256 {
      value
    } else {
      value & 0x0F
    }
    if serialized != 0 {
      return true
    }
    i = i + 1
  }
  false
}

// Format a valid SpanContext as a `traceparent` header value (version 00).
// An invalid SpanContext yields an empty string. The IDs are revalidated from
// their live serialized bytes: a caller may zero an aliased ID array through
// `trace_id_view`/`span_id_view` after construction, and an all-zero ID must
// never be written into a `traceparent` header.

///|
pub fn format_traceparent(sc : @api.SpanContext) -> String {
  if !sc.is_valid() {
    return ""
  }
  // The public `span_context` constructor aliases the caller's ID arrays and
  // `trace_id_view`/`span_id_view` expose them for mutation. A caller can
  // therefore shorten or zero an array after construction while the
  // snapshotted `is_valid` flag still reads true. Never read past the live
  // array length, and never emit an all-zero ID: the unambiguous IDs are
  // unavailable, so emit no traceparent instead.
  let trace_id = sc.trace_id_view()
  let span_id = sc.span_id_view()
  if trace_id.length() < 16 ||
    span_id.length() < 8 ||
    !has_nonzero_serialized_byte(trace_id, 16) ||
    !has_nonzero_serialized_byte(span_id, 8) {
    return ""
  }
  let flags = sc.trace_flags() & TRACE_FLAGS_KNOWN
  // `00-` + 32 trace chars + `-` + 16 span chars + `-` + 2 flag chars, each
  // character occupying two UTF-16LE bytes.
  let out = FixedArray::make(55 * 2, b'\x00')
  out.unsafe_set(0, b'0')
  out.unsafe_set(2, b'0')
  out.unsafe_set(4, b'-')
  write_hex(out, 3, trace_id, 16)
  out.unsafe_set(35 * 2, b'-')
  write_hex(out, 36, span_id, 8)
  out.unsafe_set(52 * 2, b'-')
  out.unsafe_set(53 * 2, nibble_to_hex_byte(flags >> 4))
  out.unsafe_set(54 * 2, nibble_to_hex_byte(flags & 0x0F))
  out.unsafe_reinterpret_as_bytes().to_unchecked_string()
}

// Parse a `traceparent` header value into a SpanContext.
// Leading and trailing optional whitespace (RFC 9110 OWS) is allowed.
// Returns None when the value is malformed, uses `ff` as version, contains
// all-zero IDs, or otherwise violates the specification.

///|
pub fn parse_traceparent(value : String) -> @api.SpanContext? {
  // OWS around the header value is not part of the ABNF and is trimmed.
  let trimmed = trim_ows(value[:])
  let value = if trimmed.length() == value.length() {
    value
  } else {
    trimmed.to_owned()
  }
  let len = value.length()
  // The shortest well-formed value is `00-` + 32 + `-` + 16 + `-` + 2 = 55
  // characters, so anything shorter cannot parse.
  if len < 55 {
    return None
  }
  // Any parseable value has its dashes exactly at 2, 35 and 52; a dash
  // anywhere else fails the hex decoding below.
  if value.unsafe_get(2).unsafe_to_char() != '-' ||
    value.unsafe_get(35).unsafe_to_char() != '-' ||
    value.unsafe_get(52).unsafe_to_char() != '-' {
    return None
  }
  let version_hi = value.unsafe_get(0).unsafe_to_char()
  let version_lo = value.unsafe_get(1).unsafe_to_char()
  let version_hi_value = hex_digit_value(version_hi)
  let version_lo_value = hex_digit_value(version_lo)
  if version_hi_value < 0 || version_lo_value < 0 {
    return None
  }
  if version_hi_value == 15 && version_lo_value == 15 {
    // `ff` is a reserved invalid version.
    return None
  }
  let flags_start = 53
  let flags_hi = hex_digit_value(value.unsafe_get(flags_start).unsafe_to_char())
  let flags_lo = hex_digit_value(
    value.unsafe_get(flags_start + 1).unsafe_to_char(),
  )
  if flags_hi < 0 || flags_lo < 0 {
    return None
  }
  if len > 55 && value.unsafe_get(55).unsafe_to_char() != '-' {
    // W3C Trace Context only requires the two flag characters to be followed
    // by the end of the value or by a dash. Anything after that dash is a
    // future-version extension and must not be interpreted (it may even be
    // empty, as in `01-...-01-`).
    return None
  }
  if version_hi == '0' && version_lo == '0' && len > 55 {
    // Version 00 does not allow additional fields.
    return None
  }
  if version_hi == '0' && version_lo == '0' &&
    !(has_lowercase_hex(value, 3, 32) &&
      has_lowercase_hex(value, 36, 16) &&
      has_lowercase_hex(value, 53, 2)) {
    // The version 00 ABNF spells every field `HEXDIGLC`; a header holding an
    // uppercase hex character is invalid and must be ignored. Higher
    // versions accept hex in either case.
    return None
  }
  let trace_id = match decode_hex_nonzero(value, 3, 16) {
    Some(bytes) => bytes
    None => return None
  }
  let span_id = match decode_hex_nonzero(value, 36, 8) {
    Some(bytes) => bytes
    None => return None
  }
  let flags = flags_hi * 16 + flags_lo
  // Both IDs are known to be 16/8 bytes and non-zero, so the resulting
  // context is always valid.
  Some(
    @api.span_context(
      trace_id,
      span_id,
      flags & TRACE_FLAGS_KNOWN,
      is_remote=true,
    ),
  )
}

// Upper bound on the number of cached `tracestate` parse results. The oldest
// entry (in insertion order) is evicted when the cache is full.

///|
const TRACESTATE_INJECT_CACHE_LIMIT : Int32 = 128

// Cached result of `parse_tracestate` keyed by the raw `tracestate` value:
// the normalized value when it is valid, `None` when it is not. Hits do not
// write to the cache, and eviction removes the first inserted key.

///|
let tracestate_inject_cache : Map[String, String?] = Map([])

///|
fn normalized_tracestate_for_inject(state : String) -> String? {
  match tracestate_inject_cache.get(state) {
    Some(normalized) => normalized
    None => {
      let normalized = parse_tracestate(state)
      if tracestate_inject_cache.length() >= TRACESTATE_INJECT_CACHE_LIMIT {
        // `Map` iterates in insertion order, so the first key is the oldest.
        let mut oldest : String? = None
        for key, _ in tracestate_inject_cache {
          oldest = Some(key)
          break
        }
        match oldest {
          Some(key) => tracestate_inject_cache.remove(key)
          None => ()
        }
      }
      tracestate_inject_cache.set(state, normalized)
      normalized
    }
  }
}

// Remove any trace context left in a carrier by an earlier injection. The
// context-level propagators use this when the new context has no valid span,
// so a reused carrier never sends an old trace parent alongside new baggage.

///|
fn remove_trace_context(carrier : TextMapCarrier) -> Unit {
  carrier.remove(traceparent_header_name())
  carrier.remove(tracestate_header_name())
}

// Inject a SpanContext into the carrier as a `traceparent` header, plus a
// `tracestate` header when the SpanContext carries a valid one. A stale
// `tracestate` already present in the carrier is removed when the context has
// no valid state, so it cannot be paired with the new `traceparent`.
// Does nothing when the SpanContext is invalid.

///|
pub fn inject(sc : @api.SpanContext, carrier : TextMapCarrier) -> Unit {
  if sc.is_valid() {
    let formatted = format_traceparent(sc)
    if formatted == "" {
      // The live IDs no longer form a valid traceparent (for example a caller
      // zeroed an aliased ID array). Do not write an empty header, and do not
      // leave a stale one that would be paired with an unrelated tracestate.
      remove_trace_context(carrier)
      return
    }
    // Replace any header left under a different spelling, so the carrier holds
    // exactly one `traceparent` value rather than both the old and new one.
    carrier.remove(traceparent_header_name())
    carrier.set(traceparent_header_name(), formatted)
    let state = sc.tracestate()
    if state != "" {
      match normalized_tracestate_for_inject(state) {
        Some(normalized) =>
          if normalized != "" {
            // See above: a differently-cased stale header must not survive
            // alongside the normalized value just written.
            carrier.remove(tracestate_header_name())
            carrier.set(tracestate_header_name(), normalized)
          } else {
            // The context carries no members: do not leave an unrelated
            // `tracestate` from an earlier injection attached to the new
            // `traceparent`.
            carrier.remove(tracestate_header_name())
          }
        None =>
          // An invalid state is dropped; a stale header would otherwise be
          // propagated with a `traceparent` it does not belong to.
          carrier.remove(tracestate_header_name())
      }
    } else {
      carrier.remove(tracestate_header_name())
    }
  }
}

// Extract a SpanContext from the carrier's `traceparent` header, attaching the
// `tracestate` header when it is present and valid. An invalid `tracestate`
// is ignored, as required by the specification.

///|
pub fn extract(carrier : TextMapCarrier) -> @api.SpanContext? {
  match carrier.get(traceparent_header_name()) {
    Some(value) =>
      match parse_traceparent(value) {
        Some(sc) =>
          match carrier.get(tracestate_header_name()) {
            Some(state) =>
              match parse_tracestate(state) {
                Some(normalized) => Some(sc.with_tracestate(normalized))
                None => Some(sc)
              }
            None => Some(sc)
          }
        None => None
      }
    None => None
  }
}

// Inject both `traceparent` and (when non-empty) `tracestate`.

///|
pub fn inject_with_tracestate(
  sc : @api.SpanContext,
  tracestate : String?,
  carrier : TextMapCarrier,
) -> Unit {
  if !sc.is_valid() {
    return
  }
  match tracestate {
    None =>
      // No explicit override: propagate the state carried by the context.
      inject(sc, carrier)
    Some(state) => {
      // An explicit value overrides the state carried by `sc`, including an
      // empty value (which suppresses the header) and a malformed value
      // (which is dropped instead of being written). Write only the
      // `traceparent` from the context so its state cannot leak through.
      let formatted = format_traceparent(sc)
      if formatted == "" {
        // The live IDs cannot be serialized as a valid traceparent; suppress
        // both headers rather than writing an empty or stale pair.
        carrier.remove(traceparent_header_name())
        carrier.remove(tracestate_header_name())
        return
      }
      carrier.remove(traceparent_header_name())
      carrier.set(traceparent_header_name(), formatted)
      carrier.remove(tracestate_header_name())
      if !state.is_empty() {
        match parse_tracestate(state) {
          Some(normalized) =>
            if normalized != "" {
              carrier.set(tracestate_header_name(), normalized)
            }
          None => ()
        }
      }
    }
  }
}

// Extract the raw `tracestate` header value, if present.
// The value is passed through unchanged.

///|
pub fn extract_tracestate(carrier : TextMapCarrier) -> String? {
  carrier.get(tracestate_header_name())
}

///|
fn is_lcalpha(c : Char) -> Bool {
  c >= 'a' && c <= 'z'
}

///|
fn is_digit_char(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

// Whether each ASCII code unit (0-127) may appear after the first character
// of a `tracestate` key: `lcalpha`, digit, `_`, `-`, `*`, `/` or `@`.

///|
let tracestate_key_char_table : FixedArray[Bool] = build_tracestate_key_char_table()

///|
fn build_tracestate_key_char_table() -> FixedArray[Bool] {
  let table : FixedArray[Bool] = FixedArray::make(128, false)
  let mut code = 0
  while code < 128 {
    let allowed = (code >= 48 && code <= 57) ||
      (code >= 97 && code <= 122) ||
      code == 0x5F ||
      code == 0x2D ||
      code == 0x2A ||
      code == 0x2F ||
      code == 0x40
    table.unsafe_set(code, allowed)
    code = code + 1
  }
  table
}

///|
fn is_tracestate_key_tail(c : Char) -> Bool {
  let code = c.to_int()
  code >= 0 && code < 128 && tracestate_key_char_table.unsafe_get(code)
}

// Whether each ASCII code unit (0-127) may appear in a `tracestate` value:
// printable ASCII without `,` or `=`.

///|
let tracestate_value_char_table : FixedArray[Bool] = build_tracestate_value_char_table()

///|
fn build_tracestate_value_char_table() -> FixedArray[Bool] {
  let table : FixedArray[Bool] = FixedArray::make(128, false)
  let mut code = 0
  while code < 128 {
    table.unsafe_set(
      code,
      code >= 0x20 && code <= 0x7E && code != 0x2C && code != 0x3D,
    )
    code = code + 1
  }
  table
}

// Validate a `tracestate` key using the Trace Context Level 2 grammar:
// `key = (lcalpha / DIGIT) 0*255 keychar`, where `keychar` also includes `@`.

///|
fn is_valid_tracestate_key(key : StringView) -> Bool {
  let len = key.length()
  if len == 0 || len > 256 {
    return false
  }
  let first = key.unsafe_get(0).unsafe_to_char()
  if !is_lcalpha(first) && !is_digit_char(first) {
    return false
  }
  let mut i = 1
  while i < len {
    if !is_tracestate_key_tail(key.unsafe_get(i).unsafe_to_char()) {
      return false
    }
    i = i + 1
  }
  true
}

// Validate a `tracestate` value: printable ASCII without `,` or `=`, holding
// 1 to 256 characters and ending with a non-blank character, matching the
// grammar `value = 0*255(chr) nblk-chr`.

///|
fn is_valid_tracestate_value(value : StringView) -> Bool {
  let len = value.length()
  if len == 0 || len > 256 {
    return false
  }
  let mut i = 0
  while i < len {
    let code = value.unsafe_get(i).unsafe_to_char().to_int()
    if code >= 128 || !tracestate_value_char_table.unsafe_get(code) {
      return false
    }
    i = i + 1
  }
  value.unsafe_get(len - 1).unsafe_to_char().to_int() != 0x20
}

// Write the normalized form of an already validated `tracestate` value: the
// members joined by `,` with optional whitespace trimmed. Empty and
// whitespace-only members are dropped, and a duplicated key keeps its first
// member, matching `parse_tracestate`.

///|
fn write_normalized_tracestate(view : StringView, len : Int32) -> String {
  let sb = StringBuilder(size_hint=len * 2)
  let mut count = 0
  let seen : Array[StringView] = []
  let mut start = 0
  while true {
    let end = find_code_unit(view, ',', start)
    let item = trim_ows(view.view(start_offset=start, end_offset=end))
    let mut duplicate = false
    if item.length() > 0 {
      let eq = find_code_unit(item, '=', 0)
      let key_src = item[:eq]
      let key = trim_ows(key_src)
      // Blanks after `=` belong to the value unless the member also has
      // whitespace before `=` (`key = value`).
      let value_src = item[eq + 1:]
      let member_value = if key_src.length() == key.length() {
        value_src
      } else {
        trim_ows(value_src)
      }
      for existing in seen {
        if existing == key {
          duplicate = true
          break
        }
      }
      if !duplicate {
        seen.push(key)
        if count > 0 {
          sb.write_char(',')
        }
        sb.write_stringview(key)
        sb.write_char('=')
        sb.write_stringview(member_value)
        count = count + 1
      }
    }
    if end == len {
      break
    }
    start = end + 1
  }
  sb.to_string()
}

// Validate and normalize a `tracestate` header value.
//
// The result is the list of members joined by `,` with optional whitespace
// trimmed. Empty and whitespace-only list members are allowed and dropped;
// a duplicated key keeps its first member. An empty or member-less value is
// accepted as the empty state (`Some("")`), as required by W3C Trace Context
// Level 2. Returns None when the value has more than 32 members, contains a
// malformed member or an invalid value.

///|
pub fn parse_tracestate(value : String) -> String? {
  // At most 32 list-members are accepted; duplicates keep the first entry.
  let mut first_key : StringView = ""
  let mut have_first = false
  let mut seen : Array[StringView]? = None
  let mut member_count = 0
  let view = value[:]
  let len = view.length()
  let mut start = 0
  // Set when any item needed optional whitespace trimmed.
  let mut unchanged = true
  while true {
    // Find the member end (the next `,`) together with the first `=`.
    let mut end = start
    let mut eq = -1
    while end < len {
      let c = view.unsafe_get(end)
      if c == 0x2C {
        break
      }
      if c == 0x3D && eq < 0 {
        eq = end
      }
      end = end + 1
    }
    // Trim optional whitespace around the member.
    let mut item_start = start
    while item_start < end && is_ows_code(view.unsafe_get(item_start)) {
      item_start = item_start + 1
    }
    let mut item_end = end
    while item_end > item_start && is_ows_code(view.unsafe_get(item_end - 1)) {
      item_end = item_end - 1
    }
    if item_end <= item_start {
      // Empty and whitespace-only list members are allowed by W3C and carry
      // no key/value pair; they are omitted from the normalized form.
      unchanged = false
      if end == len {
        break
      }
      start = end + 1
      continue
    }
    if member_count >= 32 {
      return None
    }
    member_count = member_count + 1
    if eq < 0 || eq >= item_end {
      return None
    }
    if item_start != start || item_end != end {
      unchanged = false
    }
    // Trim optional whitespace before the `=`.
    let mut key_end = eq
    while key_end > item_start && is_ows_code(view.unsafe_get(key_end - 1)) {
      key_end = key_end - 1
    }
    if key_end != eq {
      unchanged = false
    }
    let key = view.view(start_offset=item_start, end_offset=key_end)
    // Blanks after the `=` belong to the value; they are trimmed only when the
    // member also has whitespace before `=` (`key = value`). Trailing
    // whitespace was already removed by the member trim above.
    let mut value_start = eq + 1
    if key_end != eq {
      while value_start < item_end && is_ows_code(view.unsafe_get(value_start)) {
        value_start = value_start + 1
      }
    }
    let member_value = view.view(start_offset=value_start, end_offset=item_end)
    if !is_valid_tracestate_key(key) || !is_valid_tracestate_value(member_value) {
      return None
    }
    let mut duplicate = false
    match seen {
      Some(keys) => {
        let mut i = 0
        let n = keys.length()
        while i < n {
          if keys.unsafe_get(i) == key {
            duplicate = true
            break
          }
          i = i + 1
        }
        if !duplicate {
          keys.push(key)
        }
      }
      None =>
        if have_first {
          if first_key == key {
            duplicate = true
          } else {
            let keys : Array[StringView] = [first_key, key]
            seen = Some(keys)
          }
        } else {
          first_key = key
          have_first = true
        }
    }
    if duplicate {
      // A duplicated key keeps its first member; later members are dropped.
      unchanged = false
      if end == len {
        break
      }
      start = end + 1
      continue
    }
    if end == len {
      break
    }
    start = end + 1
  }
  if unchanged {
    Some(value)
  } else {
    let normalized = write_normalized_tracestate(view, len)
    // An empty or member-less header carries no state. It is still a valid,
    // accepted header (W3C Trace Context Level 2); callers that write headers
    // skip the empty normalized form.
    Some(normalized)
  }
}
