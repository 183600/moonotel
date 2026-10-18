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

///|
pub fn traceparent_header_name() -> String {
  "traceparent"
}

// Name of the `tracestate` header

///|
pub fn tracestate_header_name() -> String {
  "tracestate"
}

///|
fn is_trim_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

// Equivalent to `value.trim()` (the default whitespace set).

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

// Decode `byte_count` hex byte pairs starting at `start`, validating as it
// goes and tracking whether any byte is non-zero. Returns None when any
// character is not a hex digit or when every decoded byte is zero, so the
// caller never needs a second pass over the decoded ID.

///|
fn decode_hex_nonzero(
  value : String,
  start : Int32,
  byte_count : Int32,
) -> Array[Int32]? {
  // Every element is written before `Some` is returned.
  let out : Array[Int32] = Array::unsafe_make_uninit(byte_count)
  let mut acc = 0
  let mut i = 0
  while i < byte_count {
    let hi = hex_digit_value(value.unsafe_get(start + i * 2).unsafe_to_char())
    let lo = hex_digit_value(
      value.unsafe_get(start + i * 2 + 1).unsafe_to_char(),
    )
    if hi < 0 || lo < 0 {
      return None
    }
    let byte = hi * 16 + lo
    acc = acc | byte
    out.unsafe_set(i, byte)
    i = i + 1
  }
  if acc == 0 {
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

// Format a valid SpanContext as a `traceparent` header value (version 00).
// An invalid SpanContext yields an empty string.

///|
pub fn format_traceparent(sc : @api.SpanContext) -> String {
  if !sc.is_valid() {
    return ""
  }
  let flags = sc.trace_flags() & 0xFF
  // `00-` + 32 trace chars + `-` + 16 span chars + `-` + 2 flag chars, each
  // character occupying two UTF-16LE bytes.
  let out = FixedArray::make(55 * 2, b'\x00')
  out.unsafe_set(0, b'0')
  out.unsafe_set(2, b'0')
  out.unsafe_set(4, b'-')
  write_hex(out, 3, sc.trace_id_view(), 16)
  out.unsafe_set(35 * 2, b'-')
  write_hex(out, 36, sc.span_id_view(), 8)
  out.unsafe_set(52 * 2, b'-')
  out.unsafe_set(53 * 2, nibble_to_hex_byte(flags >> 4))
  out.unsafe_set(54 * 2, nibble_to_hex_byte(flags & 0x0F))
  out.unsafe_reinterpret_as_bytes().to_unchecked_string()
}

// Parse a `traceparent` header value into a SpanContext.
// Returns None when the value is malformed, uses `ff` as version, contains
// all-zero IDs, or otherwise violates the specification.

///|
pub fn parse_traceparent(value : String) -> @api.SpanContext? {
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
    return None
  }
  if version_hi == '0' && version_lo == '0' && len > 55 {
    // Version 00 does not allow additional fields.
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
      flags & @api.TRACE_FLAGS_SAMPLED,
      is_remote=true,
    ),
  )
}

// Inject a SpanContext into the carrier as a `traceparent` header, plus a
// `tracestate` header when the SpanContext carries a valid one.
// Does nothing when the SpanContext is invalid.

///|
pub fn inject(sc : @api.SpanContext, carrier : TextMapCarrier) -> Unit {
  if sc.is_valid() {
    carrier.set(traceparent_header_name(), format_traceparent(sc))
    let state = sc.tracestate()
    if state != "" {
      match parse_tracestate(state) {
        Some(normalized) => carrier.set(tracestate_header_name(), normalized)
        None => ()
      }
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

///|
fn is_tracestate_key_tail(c : Char) -> Bool {
  is_lcalpha(c) ||
  is_digit_char(c) ||
  c == '_' ||
  c == '-' ||
  c == '*' ||
  c == '/'
}

// Validate a `tracestate` key: either a simple key (`lcalpha` followed by up to
// 255 key characters) or a multi-tenant key (`tenant-id@system-id`).

///|
fn is_valid_tracestate_key(key : StringView) -> Bool {
  let len = key.length()
  if len == 0 || len > 256 {
    return false
  }
  // Validate the character set and locate the (at most one) `@`.
  let mut at = -1
  let mut i = 0
  while i < len {
    let c = key.unsafe_get(i).unsafe_to_char()
    if c == '@' {
      if at >= 0 {
        // At most one `@` per key.
        return false
      }
      at = i
    } else if !is_tracestate_key_tail(c) {
      return false
    }
    i = i + 1
  }
  if at < 0 {
    is_lcalpha(key.unsafe_get(0).unsafe_to_char())
  } else {
    let tenant_len = at
    let system_len = len - at - 1
    if tenant_len < 1 || tenant_len > 241 || system_len < 1 || system_len > 14 {
      return false
    }
    let first = key.unsafe_get(0).unsafe_to_char()
    if !is_lcalpha(first) && !is_digit_char(first) {
      return false
    }
    is_lcalpha(key.unsafe_get(at + 1).unsafe_to_char())
  }
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
    if code < 0x20 || code > 0x7E || code == 0x2C || code == 0x3D {
      return false
    }
    i = i + 1
  }
  value.unsafe_get(len - 1).unsafe_to_char().to_int() != 0x20
}

// Write the normalized form of an already validated `tracestate` value: the
// members joined by `,` with optional whitespace trimmed.

///|
fn write_normalized_tracestate(view : StringView, len : Int32) -> String {
  let sb = StringBuilder(size_hint=len * 2)
  let mut count = 0
  let mut start = 0
  while true {
    let end = find_code_unit(view, ',', start)
    let item = trim_ows(view.view(start_offset=start, end_offset=end))
    let eq = find_code_unit(item, '=', 0)
    let key = trim_ows(item[:eq])
    let member_value = trim_ows(item[eq + 1:])
    if count > 0 {
      sb.write_char(',')
    }
    sb.write_stringview(key)
    sb.write_char('=')
    sb.write_stringview(member_value)
    count = count + 1
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
// trimmed. Returns None when the value is empty, has more than 32 members,
// contains a malformed or duplicate key, or has an invalid value.

///|
pub fn parse_tracestate(value : String) -> String? {
  if value == "" {
    return None
  }
  // Duplicate keys are rejected; at most 32 members are accepted.
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
    if member_count >= 32 {
      return None
    }
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
    if item_end <= item_start || eq < 0 || eq >= item_end {
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
    // Trim optional whitespace after the `=`; trailing whitespace was already
    // removed by the member trim above.
    let mut value_start = eq + 1
    while value_start < item_end && is_ows_code(view.unsafe_get(value_start)) {
      value_start = value_start + 1
    }
    if value_start != eq + 1 {
      unchanged = false
    }
    let member_value = view.view(start_offset=value_start, end_offset=item_end)
    if !is_valid_tracestate_key(key) || !is_valid_tracestate_value(member_value) {
      return None
    }
    match seen {
      Some(keys) => {
        for existing in keys {
          if existing == key {
            return None
          }
        }
        keys.push(key)
      }
      None =>
        if have_first {
          if first_key == key {
            return None
          }
          let keys : Array[StringView] = [first_key, key]
          seen = Some(keys)
        } else {
          first_key = key
          have_first = true
        }
    }
    member_count = member_count + 1
    if end == len {
      break
    }
    start = end + 1
  }
  if unchanged {
    Some(value)
  } else {
    Some(write_normalized_tracestate(view, len))
  }
}
