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

// A growable UTF-8 byte buffer for JSON encoding. Writing bytes directly
// avoids materializing the whole payload as a UTF-16 `String` and then
// re-encoding it to UTF-8, which previously copied the entire document twice.

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
  self.buf.blit_from_bytes(self.len, bytes, 0, n)
  self.len = self.len + n
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

// Append a string view, copying ASCII runs in bulk and encoding every run of
// non-ASCII code units with `@utf8.encode` so that surrogate pairs keep the
// exact same encoding as the rest of the SDK.

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
      sb.write_string("\\\"")
    } else if code == 0x5C {
      sb.write_string("\\\\")
    } else if code == 0x08 {
      sb.write_string("\\b")
    } else if code == 0x0C {
      sb.write_string("\\f")
    } else if code == 0x0A {
      sb.write_string("\\n")
    } else if code == 0x0D {
      sb.write_string("\\r")
    } else if code == 0x09 {
      sb.write_string("\\t")
    } else {
      sb.write_string("\\u00")
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

// Append the decimal digits of an unsigned magnitude.

///|
let json_two_digits : FixedArray[String] = build_json_two_digits()

///|
fn build_json_two_digits() -> FixedArray[String] {
  let table : FixedArray[String] = FixedArray::make(100, "00")
  let mut i = 0
  while i < 100 {
    table.unsafe_set(
      i,
      String::from_array([
        (0x30 + i / 10).unsafe_to_char(),
        (0x30 + i % 10).unsafe_to_char(),
      ]),
    )
    i = i + 1
  }
  table
}

///|
fn json_write_decimal_digits(sb : JsonBuf, value : UInt64) -> Unit {
  if value < 10 {
    sb.write_char((0x30 + value.to_int()).unsafe_to_char())
    return
  }
  if value < 100 {
    sb.write_string(json_two_digits.unsafe_get(value.to_int()))
    return
  }
  let high = value / 100
  json_write_decimal_digits(sb, high)
  sb.write_string(json_two_digits.unsafe_get((value - high * 100).to_int()))
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
    sb.write_string("\"NaN\"")
  } else if value > 1.7976931348623157e308 {
    sb.write_string("\"Infinity\"")
  } else if value < -1.7976931348623157e308 {
    sb.write_string("\"-Infinity\"")
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
      sb.write_string("\"stringValue\":")
      json_write_escaped(sb, text)
    }
    @sdk.BoolValue(flag) =>
      sb.write_string(
        if flag {
          "\"boolValue\":true"
        } else {
          "\"boolValue\":false"
        },
      )
    @sdk.IntValue(number) => {
      sb.write_string("\"intValue\":")
      json_write_int64_string(sb, number)
    }
    @sdk.DoubleValue(number) => {
      sb.write_string("\"doubleValue\":")
      json_write_double(sb, number)
    }
    @sdk.StringArrayValue(items) => {
      sb.write_string("\"arrayValue\":{\"values\":[")
      let mut first = true
      for item in items {
        if !first {
          sb.write_char(',')
        }
        first = false
        sb.write_string("{\"stringValue\":")
        json_write_escaped(sb, item)
        sb.write_char('}')
      }
      sb.write_string("]}")
    }
    @sdk.BoolArrayValue(items) => {
      sb.write_string("\"arrayValue\":{\"values\":[")
      let mut first = true
      for item in items {
        if !first {
          sb.write_char(',')
        }
        first = false
        sb.write_string(
          if item {
            "{\"boolValue\":true}"
          } else {
            "{\"boolValue\":false}"
          },
        )
      }
      sb.write_string("]}")
    }
    @sdk.IntArrayValue(items) => {
      sb.write_string("\"arrayValue\":{\"values\":[")
      let mut first = true
      for item in items {
        if !first {
          sb.write_char(',')
        }
        first = false
        sb.write_string("{\"intValue\":")
        json_write_int64_string(sb, item)
        sb.write_char('}')
      }
      sb.write_string("]}")
    }
    @sdk.DoubleArrayValue(items) => {
      sb.write_string("\"arrayValue\":{\"values\":[")
      let mut first = true
      for item in items {
        if !first {
          sb.write_char(',')
        }
        first = false
        sb.write_string("{\"doubleValue\":")
        json_write_double(sb, item)
        sb.write_char('}')
      }
      sb.write_string("]}")
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
    sb.write_string("{\"key\":")
    json_write_escaped(sb, key)
    sb.write_string(",\"value\":")
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
  sb.write_string("{\"attributes\":")
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
  sb.write_string("{\"name\":")
  json_write_escaped(sb, name)
  if version != "" {
    sb.write_string(",\"version\":")
    json_write_escaped(sb, version)
  }
  sb.write_char('}')
}

// Append one `Event` message.

///|
fn json_write_event(sb : JsonBuf, event : @sdk.SpanEvent) -> Unit {
  sb.write_string("{\"timeUnixNano\":")
  json_write_int64_string(sb, event.time_unix_nano)
  sb.write_string(",\"name\":")
  json_write_escaped(sb, event.name)
  if event.attributes.length() > 0 {
    sb.write_string(",\"attributes\":")
    json_write_attributes(sb, event.attributes)
  }
  if event.dropped_attributes_count > 0 {
    sb.write_string(",\"droppedAttributesCount\":")
    json_write_int32(sb, event.dropped_attributes_count)
  }
  sb.write_char('}')
}

// Append one `Link` message.

///|
fn json_write_link(sb : JsonBuf, link : @sdk.SpanLink) -> Unit {
  sb.write_string("{\"traceId\":")
  json_write_hex_quoted(sb, link.span_context.trace_id_view())
  sb.write_string(",\"spanId\":")
  json_write_hex_quoted(sb, link.span_context.span_id_view())
  let tracestate = link.span_context.tracestate()
  if tracestate != "" {
    sb.write_string(",\"traceState\":")
    json_write_escaped(sb, tracestate)
  }
  if link.attributes.length() > 0 {
    sb.write_string(",\"attributes\":")
    json_write_attributes(sb, link.attributes)
  }
  if link.dropped_attributes_count > 0 {
    sb.write_string(",\"droppedAttributesCount\":")
    json_write_int32(sb, link.dropped_attributes_count)
  }
  sb.write_string(",\"flags\":")
  json_write_int32(sb, link.span_context.trace_flags())
  sb.write_char('}')
}

// Append the `status` message, omitted for an unset status without a
// description.

///|
fn json_write_status(sb : JsonBuf, data : @sdk.SpanData) -> Unit {
  if data.status != @api.StatusCode::Unset || data.status_description != "" {
    sb.write_string(",\"status\":{")
    let mut first = true
    if data.status_description != "" {
      sb.write_string("\"message\":")
      json_write_escaped(sb, data.status_description)
      first = false
    }
    let code = data.status.otlp_value()
    if code != 0 {
      if !first {
        sb.write_char(',')
      }
      sb.write_string("\"code\":")
      json_write_int32(sb, code)
    }
    sb.write_char('}')
  }
}

// Append one `Span` message.

///|
fn json_write_span(sb : JsonBuf, data : @sdk.SpanData) -> Unit {
  sb.write_string("{\"traceId\":")
  json_write_hex_quoted(sb, data.span_context.trace_id_view())
  sb.write_string(",\"spanId\":")
  json_write_hex_quoted(sb, data.span_context.span_id_view())
  let tracestate = data.span_context.tracestate()
  if tracestate != "" {
    sb.write_string(",\"traceState\":")
    json_write_escaped(sb, tracestate)
  }
  if data.parent_span_id.length() > 0 {
    sb.write_string(",\"parentSpanId\":")
    json_write_hex_quoted(sb, data.parent_span_id)
  }
  sb.write_string(",\"name\":")
  json_write_escaped(sb, data.name)
  sb.write_string(",\"kind\":")
  json_write_int32(sb, data.kind.otlp_value())
  sb.write_string(",\"startTimeUnixNano\":")
  json_write_int64_string(sb, data.start_time_unix_nano)
  sb.write_string(",\"endTimeUnixNano\":")
  json_write_int64_string(sb, data.end_time_unix_nano)
  if data.attributes.length() > 0 {
    sb.write_string(",\"attributes\":")
    json_write_attributes(sb, data.attributes)
  }
  if data.dropped_attributes_count > 0 {
    sb.write_string(",\"droppedAttributesCount\":")
    json_write_int32(sb, data.dropped_attributes_count)
  }
  if data.events.length() > 0 {
    sb.write_string(",\"events\":[")
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
    sb.write_string(",\"droppedEventsCount\":")
    json_write_int32(sb, data.dropped_events_count)
  }
  if data.links.length() > 0 {
    sb.write_string(",\"links\":[")
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
    sb.write_string(",\"droppedLinksCount\":")
    json_write_int32(sb, data.dropped_links_count)
  }
  json_write_status(sb, data)
  sb.write_string(",\"flags\":")
  json_write_int32(sb, data.span_context.trace_flags())
  sb.write_char('}')
}

// Encode spans as an OTLP/JSON `ExportTraceServiceRequest`. An empty batch
// yields empty bytes, mirroring the protobuf encoder.

///|
pub fn encode_trace_request_json(spans : Array[@sdk.SpanData]) -> Bytes {
  if spans.length() == 0 {
    return b""
  }
  let mut size_hint = 64
  for data in spans {
    size_hint = size_hint + estimate_span_size(data) * 2
  }
  let sb = JsonBuf::new(size_hint)
  sb.write_string("{\"resourceSpans\":[")
  let groups = group_spans(spans)
  let mut first_group = true
  for group in groups {
    if !first_group {
      sb.write_char(',')
    }
    first_group = false
    sb.write_string("{\"resource\":")
    json_write_resource(sb, group.resource)
    sb.write_string(",\"scopeSpans\":[")
    let mut first_scope = true
    for scope in group.scopes {
      if !first_scope {
        sb.write_char(',')
      }
      first_scope = false
      sb.write_string("{\"scope\":")
      json_write_scope(sb, scope.scope_name, scope.scope_version)
      sb.write_string(",\"spans\":[")
      let mut first_span = true
      for span in scope.spans {
        if !first_span {
          sb.write_char(',')
        }
        first_span = false
        json_write_span(sb, span)
      }
      sb.write_string("]}")
    }
    sb.write_string("]}")
  }
  sb.write_string("]}")
  sb.to_bytes()
}
