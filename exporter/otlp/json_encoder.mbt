// JSON (proto3 mapping) encoding of an OTLP `ExportTraceServiceRequest`.
//
// OTLP/HTTP supports two encodings: `http/protobuf` and `http/json`. The JSON
// form follows the OTLP JSON specification, which is the protobuf JSON
// mapping with these deviations:
//
// - `trace_id` / `span_id` / `parent_span_id` are lower-case hex strings
//   instead of base64;
// - 64-bit integer fields (timestamps, `intValue`) are decimal strings;
// - field names are lowerCamelCase and enum fields are their numeric values.
//
// The encoder produces the same resource/scope grouping as the protobuf
// encoder so that both encodings carry identical data.

// Hex character of a 4-bit value, lower case.

///|
fn json_hex_digit(nibble : Int32) -> Char {
  if nibble < 10 {
    (0x30 + nibble).unsafe_to_char()
  } else {
    (0x57 + nibble).unsafe_to_char()
  }
}

// Lower-case hex digit of every nibble value 0-15.

///|
let json_hex_digits : FixedArray[Char] = build_json_hex_digits()

///|
fn build_json_hex_digits() -> FixedArray[Char] {
  let table : FixedArray[Char] = FixedArray::make(16, '0')
  let mut i = 0
  while i < 16 {
    table.unsafe_set(i, json_hex_digit(i))
    i = i + 1
  }
  table
}

// UTF-8 bytes of the two lower-case hex characters of every byte value: entry
// `b` holds the high-nibble character in the low byte and the low-nibble
// character in the next byte.

///|
let json_hex_pairs : FixedArray[UInt32] = build_json_hex_pairs()

///|
fn build_json_hex_pairs() -> FixedArray[UInt32] {
  let table : FixedArray[UInt32] = FixedArray::make(256, 0U)
  let mut b = 0
  while b < 256 {
    let hi = json_hex_digit(b >> 4).to_int()
    let lo = json_hex_digit(b & 0x0F).to_int()
    table.unsafe_set(b, (hi | (lo << 8)).reinterpret_as_uint())
    b = b + 1
  }
  table
}

// A growable UTF-8 byte buffer for JSON encoding. Values are written into the
// buffer as UTF-8 bytes.

///|
priv struct JsonBuf {
  mut buf : FixedArray[Byte]
  mut len : Int32
}

///|
fn JsonBuf::new(size_hint : Int32) -> JsonBuf {
  let capacity = if size_hint < 1 { 1 } else { size_hint }
  { buf: FixedArray::make(capacity, b'\x00'), len: 0, }
}

///|
fn JsonBuf::ensure(self : JsonBuf, extra : Int32) -> Unit {
  let required = self.len + extra
  if required > self.buf.length() {
    let doubled = self.buf.length() * 2
    let capacity = if doubled > required { doubled } else { required }
    let grown : FixedArray[Byte] = FixedArray::make(capacity, b'\x00')
    grown.unsafe_blit(0, self.buf, 0, self.len)
    self.buf = grown
  }
}

///|
fn JsonBuf::write_bytes(self : JsonBuf, bytes : Bytes) -> Unit {
  let n = bytes.length()
  self.ensure(n)
  let buf = self.buf
  let pos = self.len
  if n >= 16 {
    buf.blit_from_bytes(pos, bytes, 0, n)
  } else {
    let mut i = 0
    while i + 8 <= n {
      buf.unsafe_write_uint64_le(pos + i, bytes.unsafe_read_uint64_le(i))
      i = i + 8
    }
    if i + 4 <= n {
      buf.unsafe_write_uint32_le(pos + i, bytes.unsafe_read_uint32_le(i))
      i = i + 4
    }
    if i + 2 <= n {
      buf.unsafe_write_uint16_le(pos + i, bytes.unsafe_read_uint16_le(i))
      i = i + 2
    }
    if i < n {
      buf.unsafe_set(pos + i, bytes.unsafe_get(i))
      i = i + 1
    }
  }
  self.len = pos + n
}

///|
fn JsonBuf::write_char(self : JsonBuf, c : Char) -> Unit {
  let code = c.to_int()
  if code >= 0 && code < 0x80 {
    self.ensure(1)
    self.buf.unsafe_set(self.len, code.to_byte())
    self.len = self.len + 1
  } else {
    self.write_bytes(@utf8.encode(String::from_array([c])))
  }
}

// Append a string view as UTF-8: ASCII runs are copied directly and every run
// of non-ASCII code units is encoded with `@utf8.encode` so that surrogate
// pairs keep the exact same encoding as the rest of the SDK.

///|
fn JsonBuf::write_view(self : JsonBuf, value : StringView) -> Unit {
  let len = value.length()
  let mut i = 0
  while i < len {
    let mut ascii_end = i
    while ascii_end < len && value.unsafe_get(ascii_end).to_int() < 0x80 {
      ascii_end = ascii_end + 1
    }
    if ascii_end > i {
      self.ensure(ascii_end - i)
      let buf = self.buf
      let mut pos = self.len
      let mut j = i
      while j + 4 <= ascii_end {
        let c0 = value.unsafe_get(j).to_int()
        let c1 = value.unsafe_get(j + 1).to_int()
        let c2 = value.unsafe_get(j + 2).to_int()
        let c3 = value.unsafe_get(j + 3).to_int()
        buf.unsafe_write_uint32_le(
          pos,
          (c0 | (c1 << 8) | (c2 << 16) | (c3 << 24)).reinterpret_as_uint(),
        )
        pos = pos + 4
        j = j + 4
      }
      while j < ascii_end {
        buf.unsafe_set(pos, value.unsafe_get(j).to_int().to_byte())
        pos = pos + 1
        j = j + 1
      }
      self.len = pos
    }
    if ascii_end >= len {
      break
    }
    let mut run_end = ascii_end
    while run_end < len && value.unsafe_get(run_end).to_int() >= 0x80 {
      run_end = run_end + 1
    }
    self.write_bytes(
      @utf8.encode(value.view(start_offset=ascii_end, end_offset=run_end)),
    )
    i = run_end
  }
}

///|
fn JsonBuf::write_string(self : JsonBuf, value : String) -> Unit {
  self.write_view(value[:])
}

///|
fn JsonBuf::to_bytes(self : JsonBuf) -> Bytes {
  Bytes::from_array(self.buf[:self.len])
}

// The UTF-8 hex pair of a byte value. Out-of-range values are rendered exactly
// like `@api.bytes_to_hex` does.

///|
fn json_hex_pair_of(value : Int32) -> UInt32 {
  if value >= 0 && value < 256 {
    json_hex_pairs.unsafe_get(value)
  } else {
    let hi = value >> 4
    let hi_char = if hi >= 0 && hi < 16 {
      json_hex_digits.unsafe_get(hi).to_int()
    } else {
      0x30
    }
    let lo_char = json_hex_digits.unsafe_get(value & 0x0F).to_int()
    (hi_char | (lo_char << 8)).reinterpret_as_uint()
  }
}

// Append `"<hex>"` for a byte array, writing four hex characters (two input
// bytes) per store.

///|
fn json_write_hex_quoted(sb : JsonBuf, bytes : Array[Int32]) -> Unit {
  sb.write_char('"')
  let len = bytes.length()
  sb.ensure(len * 2)
  let buf = sb.buf
  let mut pos = sb.len
  let mut i = 0
  while i + 4 <= len {
    let b0 = bytes.unsafe_get(i)
    let b1 = bytes.unsafe_get(i + 1)
    let b2 = bytes.unsafe_get(i + 2)
    let b3 = bytes.unsafe_get(i + 3)
    if (b0 | b1 | b2 | b3) >= 0 &&
      b0 < 256 &&
      b1 < 256 &&
      b2 < 256 &&
      b3 < 256 {
      buf.unsafe_write_uint64_le(
        pos,
        json_hex_pairs.unsafe_get(b0).to_uint64() |
        (json_hex_pairs.unsafe_get(b1).to_uint64() << 16) |
        (json_hex_pairs.unsafe_get(b2).to_uint64() << 32) |
        (json_hex_pairs.unsafe_get(b3).to_uint64() << 48),
      )
    } else {
      buf.unsafe_write_uint32_le(
        pos,
        json_hex_pair_of(b0) | (json_hex_pair_of(b1) << 16),
      )
      buf.unsafe_write_uint32_le(
        pos + 4,
        json_hex_pair_of(b2) | (json_hex_pair_of(b3) << 16),
      )
    }
    pos = pos + 8
    i = i + 4
  }
  while i + 2 <= len {
    buf.unsafe_write_uint32_le(
      pos,
      json_hex_pair_of(bytes.unsafe_get(i)) |
      (json_hex_pair_of(bytes.unsafe_get(i + 1)) << 16),
    )
    pos = pos + 4
    i = i + 2
  }
  if i < len {
    buf.unsafe_write_uint16_le(
      pos,
      json_hex_pair_of(bytes.unsafe_get(i)).to_uint16(),
    )
    pos = pos + 2
  }
  sb.len = pos
  sb.write_char('"')
}

// Append `value` as a JSON string literal, escaping the characters required by
// RFC 8259. Non-ASCII text is emitted verbatim (JSON documents are UTF-8).

///|
fn json_write_escaped(sb : JsonBuf, value : String) -> Unit {
  sb.write_char('"')
  let len = value.length()
  let mut i = 0
  let mut run_start = 0
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code >= 0x20 && code != 0x22 && code != 0x5C {
      i = i + 1
      continue
    }
    if run_start < i {
      sb.write_view(value.view(start_offset=run_start, end_offset=i))
    }
    if code == 0x22 {
      sb.write_bytes(b"\\\"")
    } else if code == 0x5C {
      sb.write_bytes(b"\\\\")
    } else if code == 0x08 {
      sb.write_bytes(b"\\b")
    } else if code == 0x0C {
      sb.write_bytes(b"\\f")
    } else if code == 0x0A {
      sb.write_bytes(b"\\n")
    } else if code == 0x0D {
      sb.write_bytes(b"\\r")
    } else if code == 0x09 {
      sb.write_bytes(b"\\t")
    } else {
      sb.write_bytes(b"\\u00")
      sb.write_char(json_hex_digit(code >> 4))
      sb.write_char(json_hex_digit(code & 0x0F))
    }
    i = i + 1
    run_start = i
  }
  if run_start < len {
    sb.write_view(value.view(start_offset=run_start, end_offset=len))
  }
  sb.write_char('"')
}

// ASCII byte pairs of the two digits of 0-99: the low byte holds the tens
// digit and the high byte the ones digit.

///|
let json_two_digits : FixedArray[UInt16] = build_json_two_digits()

///|
fn build_json_two_digits() -> FixedArray[UInt16] {
  let table : FixedArray[UInt16] = FixedArray::make(100, (0 : UInt16))
  let mut i = 0
  while i < 100 {
    table.unsafe_set(
      i,
      ((0x30 + i / 10) | ((0x30 + i % 10) << 8)).to_uint16(),
    )
    i = i + 1
  }
  table
}

// Append the decimal digits of an unsigned magnitude. Two digits are produced
// per division by writing pairs backwards into a 20-byte window (the maximum
// width of a 64-bit integer); the window is then moved to the front of the
// buffer.

///|
fn json_write_decimal_digits(sb : JsonBuf, value : UInt64) -> Unit {
  if value < 10 {
    sb.ensure(1)
    sb.buf.unsafe_set(sb.len, (0x30 + value.to_int()).to_byte())
    sb.len = sb.len + 1
    return
  }
  // Small values (enum numbers, flags, counters) fit in one or two table
  // writes and skip the 20-byte scratch window.
  if value < 100 {
    sb.ensure(2)
    sb.buf.unsafe_write_uint16_le(
      sb.len,
      json_two_digits.unsafe_get(value.to_int()),
    )
    sb.len = sb.len + 2
    return
  }
  if value < 10000 {
    let small = value.to_int()
    sb.ensure(4)
    let thousands = small / 1000
    if thousands > 0 {
      sb.buf.unsafe_set(sb.len, (0x30 + thousands).to_byte())
      sb.buf.unsafe_write_uint16_le(
        sb.len + 1,
        json_two_digits.unsafe_get(small / 10 % 100),
      )
      sb.buf.unsafe_set(sb.len + 3, (0x30 + small % 10).to_byte())
      sb.len = sb.len + 4
    } else {
      sb.buf.unsafe_set(sb.len, (0x30 + small / 100).to_byte())
      sb.buf.unsafe_write_uint16_le(
        sb.len + 1,
        json_two_digits.unsafe_get(small % 100),
      )
      sb.len = sb.len + 3
    }
    return
  }
  sb.ensure(20)
  let buf = sb.buf
  let start = sb.len
  let mut pos = start + 20
  let mut v = value
  // Consume four digits per division by 10000; a 64-bit value needs at most
  // five iterations.
  while v >= 10000 {
    let remainder = (v % 10000).to_int()
    pos = pos - 4
    buf.unsafe_write_uint16_le(
      pos,
      json_two_digits.unsafe_get(remainder / 100),
    )
    buf.unsafe_write_uint16_le(
      pos + 2,
      json_two_digits.unsafe_get(remainder % 100),
    )
    v = v / 10000
  }
  let tail = v.to_int()
  if tail >= 1000 {
    pos = pos - 4
    buf.unsafe_write_uint16_le(pos, json_two_digits.unsafe_get(tail / 100))
    buf.unsafe_write_uint16_le(pos + 2, json_two_digits.unsafe_get(tail % 100))
  } else if tail >= 100 {
    pos = pos - 3
    buf.unsafe_set(pos, (0x30 + tail / 100).to_byte())
    buf.unsafe_write_uint16_le(
      pos + 1,
      json_two_digits.unsafe_get(tail % 100),
    )
  } else if tail >= 10 {
    pos = pos - 2
    buf.unsafe_write_uint16_le(pos, json_two_digits.unsafe_get(tail))
  } else {
    pos = pos - 1
    buf.unsafe_set(pos, (0x30 + tail).to_byte())
  }
  let digits = start + 20 - pos
  if pos != start {
    buf.unsafe_blit(start, buf, pos, digits)
  }
  sb.len = start + digits
}

// Append a 32-bit integer as a JSON number, spelled exactly like
// `Int32::to_string`.

///|
fn json_write_int32(sb : JsonBuf, value : Int32) -> Unit {
  if value < 0 {
    sb.write_char('-')
    json_write_decimal_digits(
      sb,
      (0L - value.to_int64()).reinterpret_as_uint64(),
    )
  } else {
    json_write_decimal_digits(sb, value.to_uint64())
  }
}

// Append the 32-bit pattern of `value` as its unsigned decimal number, the
// protobuf JSON representation of `uint32` fields (for example `flags`).

///|
fn json_write_uint32(sb : JsonBuf, value : Int32) -> Unit {
  json_write_decimal_digits(sb, value.reinterpret_as_uint().to_uint64())
}

// Append a 64-bit integer as a JSON string, the protobuf JSON representation
// of `int64`/`uint64` values.

///|
fn json_write_int64_string(sb : JsonBuf, value : Int64) -> Unit {
  sb.write_char('"')
  if value < 0L {
    sb.write_char('-')
    // `0L - value` wraps for the minimum value and yields its magnitude.
    json_write_decimal_digits(sb, (0L - value).reinterpret_as_uint64())
  } else {
    json_write_decimal_digits(sb, value.reinterpret_as_uint64())
  }
  sb.write_char('"')
}

// Append a double as a JSON number. Non-finite values are encoded as the
// strings "NaN", "Infinity" and "-Infinity", as required by the protobuf JSON
// mapping.

///|
fn json_write_double(sb : JsonBuf, value : Double) -> Unit {
  if value.is_nan() {
    sb.write_bytes(b"\"NaN\"")
  } else if value > 1.7976931348623157e308 {
    sb.write_bytes(b"\"Infinity\"")
  } else if value < -1.7976931348623157e308 {
    sb.write_bytes(b"\"-Infinity\"")
  } else {
    sb.write_string(value.to_string())
  }
}

// Append one `AnyValue` message.

///|
fn json_write_any_value(
  sb : JsonBuf,
  value : @sdk.AttributeValue,
) -> Unit {
  sb.write_char('{')
  match value {
    @sdk.StringValue(text) => {
      sb.write_bytes(b"\"stringValue\":")
      json_write_escaped(sb, text)
    }
    @sdk.BoolValue(flag) =>
      sb.write_bytes(
        if flag {
          b"\"boolValue\":true"
        } else {
          b"\"boolValue\":false"
        },
      )
    @sdk.IntValue(number) => {
      sb.write_bytes(b"\"intValue\":")
      json_write_int64_string(sb, number)
    }
    @sdk.DoubleValue(number) => {
      sb.write_bytes(b"\"doubleValue\":")
      json_write_double(sb, number)
    }
    @sdk.StringArrayValue(items) => {
      sb.write_bytes(b"\"arrayValue\":{\"values\":[")
      let mut first = true
      for item in items {
        if !first {
          sb.write_char(',')
        }
        first = false
        sb.write_bytes(b"{\"stringValue\":")
        json_write_escaped(sb, item)
        sb.write_char('}')
      }
      sb.write_bytes(b"]}")
    }
    @sdk.BoolArrayValue(items) => {
      sb.write_bytes(b"\"arrayValue\":{\"values\":[")
      let mut first = true
      for item in items {
        if !first {
          sb.write_char(',')
        }
        first = false
        sb.write_bytes(
          if item {
            b"{\"boolValue\":true}"
          } else {
            b"{\"boolValue\":false}"
          },
        )
      }
      sb.write_bytes(b"]}")
    }
    @sdk.IntArrayValue(items) => {
      sb.write_bytes(b"\"arrayValue\":{\"values\":[")
      let mut first = true
      for item in items {
        if !first {
          sb.write_char(',')
        }
        first = false
        sb.write_bytes(b"{\"intValue\":")
        json_write_int64_string(sb, item)
        sb.write_char('}')
      }
      sb.write_bytes(b"]}")
    }
    @sdk.DoubleArrayValue(items) => {
      sb.write_bytes(b"\"arrayValue\":{\"values\":[")
      let mut first = true
      for item in items {
        if !first {
          sb.write_char(',')
        }
        first = false
        sb.write_bytes(b"{\"doubleValue\":")
        json_write_double(sb, item)
        sb.write_char('}')
      }
      sb.write_bytes(b"]}")
    }
  }
  sb.write_char('}')
}

// Append a `repeated KeyValue` array.

///|
fn json_write_attributes(
  sb : JsonBuf,
  attributes : Map[String, @sdk.AttributeValue],
) -> Unit {
  sb.write_char('[')
  let mut first = true
  for key, value in attributes {
    if !first {
      sb.write_char(',')
    }
    first = false
    sb.write_bytes(b"{\"key\":")
    json_write_escaped(sb, key)
    sb.write_bytes(b",\"value\":")
    json_write_any_value(sb, value)
    sb.write_char('}')
  }
  sb.write_char(']')
}

// Append the `resource` message.

///|
fn json_write_resource(
  sb : JsonBuf,
  resource : Map[String, @sdk.AttributeValue],
) -> Unit {
  sb.write_bytes(b"{\"attributes\":")
  json_write_attributes(sb, resource)
  sb.write_char('}')
}

// Append the `instrumentation_scope` message.

///|
fn json_write_scope(
  sb : JsonBuf,
  name : String,
  version : String,
) -> Unit {
  sb.write_bytes(b"{\"name\":")
  json_write_escaped(sb, name)
  if version != "" {
    sb.write_bytes(b",\"version\":")
    json_write_escaped(sb, version)
  }
  sb.write_char('}')
}

// Append one `Event` message.

///|
fn json_write_event(sb : JsonBuf, event : @sdk.SpanEvent) -> Unit {
  sb.write_bytes(b"{\"timeUnixNano\":")
  json_write_int64_string(sb, event.time_unix_nano)
  sb.write_bytes(b",\"name\":")
  json_write_escaped(sb, event.name)
  if event.attributes.length() > 0 {
    sb.write_bytes(b",\"attributes\":")
    json_write_attributes(sb, event.attributes)
  }
  if event.dropped_attributes_count > 0 {
    sb.write_bytes(b",\"droppedAttributesCount\":")
    json_write_int32(sb, event.dropped_attributes_count)
  }
  sb.write_char('}')
}

// Append one `Link` message.

///|
fn json_write_link(sb : JsonBuf, link : @sdk.SpanLink) -> Unit {
  sb.write_bytes(b"{\"traceId\":")
  json_write_hex_quoted(sb, link.span_context.trace_id_view())
  sb.write_bytes(b",\"spanId\":")
  json_write_hex_quoted(sb, link.span_context.span_id_view())
  let tracestate = link.span_context.tracestate()
  if tracestate != "" {
    sb.write_bytes(b",\"traceState\":")
    json_write_escaped(sb, tracestate)
  }
  if link.attributes.length() > 0 {
    sb.write_bytes(b",\"attributes\":")
    json_write_attributes(sb, link.attributes)
  }
  if link.dropped_attributes_count > 0 {
    sb.write_bytes(b",\"droppedAttributesCount\":")
    json_write_int32(sb, link.dropped_attributes_count)
  }
  sb.write_bytes(b",\"flags\":")
  json_write_uint32(sb, link.span_context.trace_flags())
  sb.write_char('}')
}

// Append the `status` message, omitted for an unset status without a
// description.

///|
fn json_write_status(sb : JsonBuf, data : @sdk.SpanData) -> Unit {
  if data.status != @api.StatusCode::Unset || data.status_description != "" {
    sb.write_bytes(b",\"status\":{")
    let mut first = true
    if data.status_description != "" {
      sb.write_bytes(b"\"message\":")
      json_write_escaped(sb, data.status_description)
      first = false
    }
    let code = data.status.otlp_value()
    if code != 0 {
      if !first {
        sb.write_char(',')
      }
      sb.write_bytes(b"\"code\":")
      json_write_int32(sb, code)
    }
    sb.write_char('}')
  }
}

// Append one `Span` message.

///|
fn json_write_span(sb : JsonBuf, data : @sdk.SpanData) -> Unit {
  sb.write_bytes(b"{\"traceId\":")
  json_write_hex_quoted(sb, data.span_context.trace_id_view())
  sb.write_bytes(b",\"spanId\":")
  json_write_hex_quoted(sb, data.span_context.span_id_view())
  let tracestate = data.span_context.tracestate()
  if tracestate != "" {
    sb.write_bytes(b",\"traceState\":")
    json_write_escaped(sb, tracestate)
  }
  if data.parent_span_id.length() > 0 {
    sb.write_bytes(b",\"parentSpanId\":")
    json_write_hex_quoted(sb, data.parent_span_id)
  }
  sb.write_bytes(b",\"name\":")
  json_write_escaped(sb, data.name)
  sb.write_bytes(b",\"kind\":")
  json_write_int32(sb, data.kind.otlp_value())
  sb.write_bytes(b",\"startTimeUnixNano\":")
  json_write_int64_string(sb, data.start_time_unix_nano)
  sb.write_bytes(b",\"endTimeUnixNano\":")
  json_write_int64_string(sb, data.end_time_unix_nano)
  if data.attributes.length() > 0 {
    sb.write_bytes(b",\"attributes\":")
    json_write_attributes(sb, data.attributes)
  }
  if data.dropped_attributes_count > 0 {
    sb.write_bytes(b",\"droppedAttributesCount\":")
    json_write_int32(sb, data.dropped_attributes_count)
  }
  if data.events.length() > 0 {
    sb.write_bytes(b",\"events\":[")
    let mut first = true
    for event in data.events {
      if !first {
        sb.write_char(',')
      }
      first = false
      json_write_event(sb, event)
    }
    sb.write_char(']')
  }
  if data.dropped_events_count > 0 {
    sb.write_bytes(b",\"droppedEventsCount\":")
    json_write_int32(sb, data.dropped_events_count)
  }
  if data.links.length() > 0 {
    sb.write_bytes(b",\"links\":[")
    let mut first = true
    for link in data.links {
      if !first {
        sb.write_char(',')
      }
      first = false
      json_write_link(sb, link)
    }
    sb.write_char(']')
  }
  if data.dropped_links_count > 0 {
    sb.write_bytes(b",\"droppedLinksCount\":")
    json_write_int32(sb, data.dropped_links_count)
  }
  json_write_status(sb, data)
  sb.write_bytes(b",\"flags\":")
  json_write_uint32(sb, data.span_context.trace_flags())
  sb.write_char('}')
}

// Encode spans as an OTLP/JSON `ExportTraceServiceRequest`. An empty batch
// yields empty bytes, mirroring the protobuf encoder.

///|
pub fn encode_trace_request_json(spans : Array[@sdk.SpanData]) -> Bytes {
  if spans.length() == 0 {
    return b""
  }
  // When every span shares the same resource and scope, they form a single
  // resource/scope group.
  let first = spans[0]
  let shared_resource = first.resource.as_map()
  let mut uniform = true
  for i = 1; i < spans.length(); i = i + 1 {
    let data = spans[i]
    if !physical_equal(shared_resource, data.resource.as_map()) ||
      data.scope_name != first.scope_name ||
      data.scope_version != first.scope_version {
      uniform = false
      break
    }
  }
  if uniform {
    let mut spans_hint = 0
    for data in spans {
      spans_hint = spans_hint + estimate_span_size(data)
    }
    let size_hint = 64 +
      resource_size_hint(shared_resource) * 2 +
      (32 +
        first.scope_name.length() +
        first.scope_version.length() +
        spans_hint) *
      2
    let sb = JsonBuf::new(size_hint)
    sb.write_bytes(b"{\"resourceSpans\":[{\"resource\":")
    json_write_resource(sb, shared_resource)
    sb.write_bytes(b",\"scopeSpans\":[{\"scope\":")
    json_write_scope(sb, first.scope_name, first.scope_version)
    sb.write_bytes(b",\"spans\":[")
    let mut first_span = true
    for data in spans {
      if !first_span {
        sb.write_char(',')
      }
      first_span = false
      json_write_span(sb, data)
    }
    sb.write_bytes(b"]}]}]}")
    return sb.to_bytes()
  }
  let groups = group_spans(spans)
  let mut size_hint = 64
  for group in groups {
    // Resource attributes are emitted by every group as well; JSON quotes and
    // escapes them, so their binary estimate is doubled like the span payload.
    size_hint = size_hint + resource_size_hint(group.resource) * 2
    for scope in group.scopes {
      size_hint = size_hint + scope_size_hint(scope) * 2
    }
  }
  let sb = JsonBuf::new(size_hint)
  sb.write_bytes(b"{\"resourceSpans\":[")
  let mut first_group = true
  for group in groups {
    if !first_group {
      sb.write_char(',')
    }
    first_group = false
    sb.write_bytes(b"{\"resource\":")
    json_write_resource(sb, group.resource)
    sb.write_bytes(b",\"scopeSpans\":[")
    let mut first_scope = true
    for scope in group.scopes {
      if !first_scope {
        sb.write_char(',')
      }
      first_scope = false
      sb.write_bytes(b"{\"scope\":")
      json_write_scope(sb, scope.scope_name, scope.scope_version)
      sb.write_bytes(b",\"spans\":[")
      let mut first_span = true
      for span in scope.spans {
        if !first_span {
          sb.write_char(',')
        }
        first_span = false
        json_write_span(sb, span)
      }
      sb.write_bytes(b"]}")
    }
    sb.write_bytes(b"]}")
  }
  sb.write_bytes(b"]}")
  sb.to_bytes()
}
