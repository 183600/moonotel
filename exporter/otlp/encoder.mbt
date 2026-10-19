// Encodes SDK SpanData into an OTLP `ExportTraceServiceRequest` protobuf
// message (opentelemetry-proto v1 trace service).

// Encode one typed array element into its `AnyValue` form (field 5 of the
// enclosing `AnyValue` holds the repeated elements).

///|
fn encode_string_array(writer : ProtoWriter, items : Array[String]) -> Unit {
  let array = writer.take_scratch()
  for item in items {
    let element = array.take_scratch()
    element.write_string_field(1, item)
    array.append_message(1, element)
  }
  writer.append_message(5, array)
}

///|
fn encode_bool_array(writer : ProtoWriter, items : Array[Bool]) -> Unit {
  let array = writer.take_scratch()
  for item in items {
    let element = array.take_scratch()
    element.write_bool_field(2, item)
    array.append_message(1, element)
  }
  writer.append_message(5, array)
}

///|
fn encode_int_array(writer : ProtoWriter, items : Array[Int64]) -> Unit {
  let array = writer.take_scratch()
  for item in items {
    let element = array.take_scratch()
    element.write_varint_field(3, item.reinterpret_as_uint64())
    array.append_message(1, element)
  }
  writer.append_message(5, array)
}

///|
fn encode_double_array(writer : ProtoWriter, items : Array[Double]) -> Unit {
  let array = writer.take_scratch()
  for item in items {
    let element = array.take_scratch()
    element.write_double_field(4, item)
    array.append_message(1, element)
  }
  writer.append_message(5, array)
}

///|
fn encode_any_value(writer : ProtoWriter, value : @sdk.AttributeValue) -> Unit {
  match value {
    @sdk.StringValue(text) => writer.write_string_field(1, text)
    @sdk.BoolValue(flag) => writer.write_bool_field(2, flag)
    @sdk.IntValue(number) =>
      writer.write_varint_field(3, number.reinterpret_as_uint64())
    @sdk.DoubleValue(number) => writer.write_double_field(4, number)
    @sdk.StringArrayValue(items) => encode_string_array(writer, items)
    @sdk.BoolArrayValue(items) => encode_bool_array(writer, items)
    @sdk.IntArrayValue(items) => encode_int_array(writer, items)
    @sdk.DoubleArrayValue(items) => encode_double_array(writer, items)
  }
}

// Number of bytes a varint takes on the wire.

///|
fn varint_size(value : UInt64) -> Int32 {
  if value < 0x80 {
    1
  } else if value < 0x4000 {
    2
  } else if value < 0x200000 {
    3
  } else if value < 0x10000000 {
    4
  } else if value < 0x800000000 {
    5
  } else if value < 0x40000000000 {
    6
  } else if value < 0x2000000000000 {
    7
  } else if value < 0x100000000000000 {
    8
  } else if value < 0x8000000000000000 {
    9
  } else {
    10
  }
}

// Append the KeyValue and AnyValue headers for an attribute whose encoded
// AnyValue payload is `any_size` bytes, reserving room for the whole
// attribute (key and payload included). `key_len` is the key length in code
// units; it equals the byte length when the key is ASCII.

///|
fn write_scalar_attribute_header(
  writer : ProtoWriter,
  field : Int32,
  key_len : Int32,
  any_size : Int32,
) -> Unit {
  if field < 16 && key_len < 0x80 && any_size < 0x80 {
    let kv_size = key_len + any_size + 4
    if kv_size < 0x80 {
      let total = kv_size + 2
      if writer.len + total > writer.buf.length() {
        writer.reserve(total)
      }
      writer.buf.unsafe_write_uint32_le(
        writer.len,
        ((field << 3) | 2).reinterpret_as_uint() |
        (kv_size.reinterpret_as_uint() << 8) |
        ((0x0A : UInt32) << 16) |
        (key_len.reinterpret_as_uint() << 24),
      )
      writer.len = writer.len + 4
      return
    }
  }
  let key_size = 1 + varint_size(key_len.to_uint64()) + key_len
  let kv_size = key_size + 1 + varint_size(any_size.to_uint64()) + any_size
  let total = 1 + varint_size(kv_size.to_uint64()) + kv_size
  if writer.len + total > writer.buf.length() {
    writer.reserve(total)
  }
  writer.write_tag(field, 2)
  writer.write_varint(kv_size.to_uint64())
  writer.write_tag(1, 2)
  writer.write_varint(key_len.to_uint64())
}

// Encode one scalar attribute directly into `writer`. Strings are assumed to
// be ASCII (one byte per code unit); when a non-ASCII code unit shows up the
// partial write is rolled back and false is returned so the caller can use
// the generic path.

///|
fn try_encode_scalar_attribute(
  writer : ProtoWriter,
  field : Int32,
  key : String,
  value : @sdk.AttributeValue,
) -> Bool {
  let key_len = key.length()
  let mark = writer.len
  match value {
    @sdk.StringValue(text) => {
      let value_len = text.length()
      let any_size = 1 + varint_size(value_len.to_uint64()) + value_len
      write_scalar_attribute_header(writer, field, key_len, any_size)
      if !writer.try_write_ascii_raw(key) {
        writer.len = mark
        return false
      }
      if any_size < 0x80 {
        writer.buf.unsafe_write_uint32_le(
          writer.len,
          (0x12 : UInt32) |
          (any_size.reinterpret_as_uint() << 8) |
          ((0x0A : UInt32) << 16) |
          (value_len.reinterpret_as_uint() << 24),
        )
        writer.len = writer.len + 4
      } else {
        writer.write_tag(2, 2)
        writer.write_varint(any_size.to_uint64())
        writer.write_tag(1, 2)
        writer.write_varint(value_len.to_uint64())
      }
      if !writer.try_write_ascii_raw(text) {
        writer.len = mark
        return false
      }
      true
    }
    @sdk.BoolValue(flag) => {
      write_scalar_attribute_header(writer, field, key_len, 2)
      if !writer.try_write_ascii_raw(key) {
        writer.len = mark
        return false
      }
      writer.buf.unsafe_write_uint32_le(
        writer.len,
        (0x12 : UInt32) |
        (0x02U << 8) |
        ((0x10 : UInt32) << 16) |
        ((if flag { 0x01U } else { 0x00U }) << 24),
      )
      writer.len = writer.len + 4
      true
    }
    @sdk.IntValue(number) => {
      let bits = number.reinterpret_as_uint64()
      let any_size = 1 + varint_size(bits)
      write_scalar_attribute_header(writer, field, key_len, any_size)
      if !writer.try_write_ascii_raw(key) {
        writer.len = mark
        return false
      }
      if bits < 0x80 {
        writer.buf.unsafe_write_uint32_le(
          writer.len,
          (0x12 : UInt32) |
          (0x02U << 8) |
          ((0x18 : UInt32) << 16) |
          (bits.to_uint() << 24),
        )
        writer.len = writer.len + 4
      } else {
        writer.write_tag(2, 2)
        writer.write_varint(any_size.to_uint64())
        writer.write_varint_field(3, bits)
      }
      true
    }
    @sdk.DoubleValue(number) => {
      write_scalar_attribute_header(writer, field, key_len, 9)
      if !writer.try_write_ascii_raw(key) {
        writer.len = mark
        return false
      }
      writer.buf.unsafe_write_uint32_le(
        writer.len,
        (0x12 : UInt32) | (0x09U << 8) | ((0x21 : UInt32) << 16),
      )
      writer.buf.unsafe_write_uint64_le(
        writer.len + 3,
        number.reinterpret_as_uint64(),
      )
      writer.len = writer.len + 11
      true
    }
    _ => false
  }
}

///|
fn encode_attributes(
  writer : ProtoWriter,
  field : Int32,
  attributes : Map[String, @sdk.AttributeValue],
) -> Unit {
  if attributes.length() == 0 {
    return
  }
  for key, value in attributes {
    if !try_encode_scalar_attribute(writer, field, key, value) {
      let kv = writer.take_scratch()
      kv.write_string_field(1, key)
      let any_value = kv.take_scratch()
      encode_any_value(any_value, value)
      kv.append_message(2, any_value)
      writer.append_message(field, kv)
    }
  }
}

///|
fn encode_resource(
  writer : ProtoWriter,
  resource : Map[String, @sdk.AttributeValue],
) -> Unit {
  let resource_writer = writer.take_scratch()
  encode_attributes(resource_writer, 1, resource)
  writer.append_message(1, resource_writer)
}

///|
fn encode_scope(writer : ProtoWriter, name : String, version : String) -> Unit {
  let scope = writer.take_scratch()
  scope.write_string_field(1, name)
  if version != "" {
    scope.write_string_field(2, version)
  }
  writer.append_message(1, scope)
}

///|
fn encode_event(writer : ProtoWriter, event : @sdk.SpanEvent) -> Unit {
  let event_writer = writer.take_scratch()
  event_writer.write_fixed64_field(
    1,
    event.time_unix_nano.reinterpret_as_uint64(),
  )
  event_writer.write_string_field(2, event.name)
  encode_attributes(event_writer, 3, event.attributes)
  if event.dropped_attributes_count > 0 {
    event_writer.write_varint_field(
      4,
      event.dropped_attributes_count.to_uint64(),
    )
  }
  writer.append_message(11, event_writer)
}

///|
fn encode_link(writer : ProtoWriter, link : @sdk.SpanLink) -> Unit {
  let link_writer = writer.take_scratch()
  link_writer.write_bytes_from_int_array(1, link.span_context.trace_id_view())
  link_writer.write_bytes_from_int_array(2, link.span_context.span_id_view())
  let tracestate = link.span_context.tracestate()
  if tracestate != "" {
    link_writer.write_string_field(3, tracestate)
  }
  encode_attributes(link_writer, 4, link.attributes)
  if link.dropped_attributes_count > 0 {
    link_writer.write_varint_field(5, link.dropped_attributes_count.to_uint64())
  }
  link_writer.write_fixed32_field(
    6,
    link.span_context.trace_flags().reinterpret_as_uint(),
  )
  writer.append_message(13, link_writer)
}

///|
fn encode_status(writer : ProtoWriter, data : @sdk.SpanData) -> Unit {
  if data.status != @api.StatusCode::Unset || data.status_description != "" {
    let status = writer.take_scratch()
    if data.status_description != "" {
      status.write_string_field(2, data.status_description)
    }
    let code = data.status.otlp_value()
    if code != 0 {
      status.write_varint_field(3, code.to_uint64())
    }
    writer.append_message(15, status)
  }
}

///|
fn encode_span(writer : ProtoWriter, data : @sdk.SpanData) -> Unit {
  let span = writer.take_scratch()
  span.write_bytes_from_int_array(1, data.span_context.trace_id_view())
  span.write_bytes_from_int_array(2, data.span_context.span_id_view())
  let tracestate = data.span_context.tracestate()
  if tracestate != "" {
    span.write_string_field(3, tracestate)
  }
  if data.parent_span_id.length() > 0 {
    span.write_bytes_from_int_array(4, data.parent_span_id)
  }
  span.write_string_field(5, data.name)
  span.write_varint_field(6, data.kind.otlp_value().to_uint64())
  span.write_fixed64_field(7, data.start_time_unix_nano.reinterpret_as_uint64())
  span.write_fixed64_field(8, data.end_time_unix_nano.reinterpret_as_uint64())
  encode_attributes(span, 9, data.attributes)
  if data.dropped_attributes_count > 0 {
    span.write_varint_field(10, data.dropped_attributes_count.to_uint64())
  }
  for event in data.events {
    encode_event(span, event)
  }
  if data.dropped_events_count > 0 {
    span.write_varint_field(12, data.dropped_events_count.to_uint64())
  }
  for link in data.links {
    encode_link(span, link)
  }
  if data.dropped_links_count > 0 {
    span.write_varint_field(14, data.dropped_links_count.to_uint64())
  }
  encode_status(span, data)
  span.write_fixed32_field(
    16,
    data.span_context.trace_flags().reinterpret_as_uint(),
  )
  writer.append_message(2, span)
}

// Append the decimal digits of a non-negative integer.

///|
fn write_decimal(sb : StringBuilder, value : Int32) -> Unit {
  if value >= 10 {
    write_decimal(sb, value / 10)
  }
  sb.write_char((0x30 + value % 10).unsafe_to_char())
}

///|
fn resource_key_value(sb : StringBuilder, value : @sdk.AttributeValue) -> Unit {
  match value {
    @sdk.StringValue(text) => {
      sb.write_char('s')
      write_decimal(sb, text.length())
      sb.write_char(':')
      sb.write_string(text)
    }
    @sdk.BoolValue(flag) => sb.write_string(if flag { "b1" } else { "b0" })
    @sdk.IntValue(number) => {
      sb.write_char('i')
      sb.write_string(number.to_string())
      sb.write_char(';')
    }
    @sdk.DoubleValue(number) => {
      sb.write_char('d')
      sb.write_string(number.reinterpret_as_uint64().to_string())
      sb.write_char(';')
    }
    @sdk.StringArrayValue(items) => {
      sb.write_string("a")
      write_decimal(sb, items.length())
      sb.write_char(':')
      for item in items {
        write_decimal(sb, item.length())
        sb.write_char(':')
        sb.write_string(item)
      }
    }
    @sdk.BoolArrayValue(items) => {
      sb.write_string("ab")
      write_decimal(sb, items.length())
      sb.write_char(':')
      for item in items {
        sb.write_char(if item { '1' } else { '0' })
      }
    }
    @sdk.IntArrayValue(items) => {
      sb.write_string("ai")
      for item in items {
        sb.write_string(item.to_string())
        sb.write_char(';')
      }
    }
    @sdk.DoubleArrayValue(items) => {
      sb.write_string("ad")
      for item in items {
        sb.write_string(item.reinterpret_as_uint64().to_string())
        sb.write_char(';')
      }
    }
  }
}

// Canonical key for grouping spans that share a resource.

///|
fn resource_key(resource : Map[String, @sdk.AttributeValue]) -> String {
  let entries : Array[(String, @sdk.AttributeValue)] = Array(
    capacity=resource.length(),
  )
  for key, value in resource {
    entries.push((key, value))
  }
  entries.sort_by(fn(a, b) { a.0.compare(b.0) })
  let sb = StringBuilder()
  for entry in entries {
    let (key, value) = entry
    write_decimal(sb, key.length())
    sb.write_char(':')
    sb.write_string(key)
    sb.write_char('=')
    resource_key_value(sb, value)
  }
  sb.to_string()
}

///|
priv struct ScopeGroup {
  scope_name : String
  scope_version : String
  spans : Array[@sdk.SpanData]
  mut size_hint : Int32
}

///|
priv struct ResourceGroup {
  resource : Map[String, @sdk.AttributeValue]
  scopes : Array[ScopeGroup]
  mut size_hint : Int32
  // Index of `(scope_name, scope_version)` into `scopes`, built lazily when a
  // group with several interleaved scopes is first looked up.
  mut scope_index : Map[(String, String), Int32]?
}

// Find the scope group with the given name and version inside a resource
// group. Scope groups are unique per resource group, so the first match is the
// only match.

///|
fn find_scope_group(
  group : ResourceGroup,
  scope_name : String,
  scope_version : String,
) -> ScopeGroup? {
  match group.scope_index {
    Some(index) =>
      match index.get((scope_name, scope_version)) {
        Some(at) => Some(group.scopes[at])
        None => None
      }
    None => {
      let index : Map[(String, String), Int32] = Map([])
      let mut found : ScopeGroup? = None
      for at, scope in group.scopes {
        index.set((scope.scope_name, scope.scope_version), at)
        if found is None &&
          scope.scope_name == scope_name &&
          scope.scope_version == scope_version {
          found = Some(scope)
        }
      }
      group.scope_index = Some(index)
      found
    }
  }
}

// Extra bytes contributed by an attribute beyond its count-based allowance:
// the length of string payloads, which dominate the encoded size of long
// values (URLs, SQL, error messages).

///|
fn estimate_attribute_value_size(value : @sdk.AttributeValue) -> Int32 {
  match value {
    @sdk.StringValue(text) => text.length()
    @sdk.StringArrayValue(items) => {
      let mut size = 0
      for item in items {
        size = size + item.length()
      }
      size
    }
    _ => 0
  }
}

///|
fn estimate_attributes_size(
  attributes : Map[String, @sdk.AttributeValue],
) -> Int32 {
  let mut size = attributes.length() * 40
  for key, value in attributes {
    size = size + key.length() + estimate_attribute_value_size(value)
  }
  size
}

// Rough encoded size of one span, used to size the scratch buffers. Attribute
// values are approximated by their count plus the length of their string
// payloads; numeric and boolean arrays may still be over- or under-estimated
// slightly, which only affects the initial buffer capacity.

///|
fn estimate_span_size(data : @sdk.SpanData) -> Int32 {
  let mut size = 96 + data.name.length() + estimate_attributes_size(
    data.attributes,
  )
  for event in data.events {
    size = size +
      64 +
      event.name.length() +
      estimate_attributes_size(event.attributes)
  }
  for link in data.links {
    size = size + 64 + estimate_attributes_size(link.attributes)
  }
  size
}

// Canonical keys of resources already seen while grouping a batch, matched by
// physical identity. Switching back and forth between resources therefore does
// not rebuild the canonical key string for every span.

///|
fn cached_resource_key(
  resource : Map[String, @sdk.AttributeValue],
  cache : Array[(Map[String, @sdk.AttributeValue], String)],
) -> String {
  for entry in cache {
    if physical_equal(entry.0, resource) {
      return entry.1
    }
  }
  let key = resource_key(resource)
  cache.push((resource, key))
  key
}

///|
fn group_spans(spans : Array[@sdk.SpanData]) -> Array[ResourceGroup] {
  let groups : Array[ResourceGroup] = []
  let mut resource_index : Map[String, Int32]? = None
  let mut last_resource : Map[String, @sdk.AttributeValue]? = None
  // Index of the group for `last_resource`.
  let mut last_index = -1
  // Whether the key of `groups[last_index]` has not been registered in
  // `resource_index` yet.
  let mut unindexed = false
  // Keys of resources already seen, keyed by physical identity.
  let known_resource_keys : Array[(Map[String, @sdk.AttributeValue], String)] = []
  // Scope group of the last matched span.
  let mut cached_group_index = -1
  let mut cached_scope : ScopeGroup? = None
  for data in spans {
    let data_resource = data.resource.as_map()
    let index = match last_resource {
      Some(resource) =>
        if physical_equal(resource, data_resource) ||
          resource == data_resource {
          last_index
        } else {
          if unindexed {
            let index_map : Map[String, Int32] = match resource_index {
              Some(map) => map
              None => {
                let map : Map[String, Int32] = Map([])
                resource_index = Some(map)
                map
              }
            }
            // The key of a newly created group is computed lazily, on the
            // first switch away from it.
            let key = cached_resource_key(
              groups[last_index].resource,
              known_resource_keys,
            )
            index_map.set(key, last_index)
            unindexed = false
          }
          let key = cached_resource_key(data_resource, known_resource_keys)
          let known : Int32? = match resource_index {
            Some(map) => map.get(key)
            None => None
          }
          match known {
            Some(index) => index
            None => {
              let created : ResourceGroup = {
                resource: data_resource,
                scopes: [],
                size_hint: 0,
                scope_index: None,
              }
              groups.push(created)
              unindexed = true
              groups.length() - 1
            }
          }
        }
      None => {
        let created : ResourceGroup = {
          resource: data_resource,
          scopes: [],
          size_hint: 0,
          scope_index: None,
        }
        groups.push(created)
        unindexed = true
        groups.length() - 1
      }
    }
    last_resource = Some(data_resource)
    last_index = index
    let target = groups[index]
    let span_hint = estimate_span_size(data)
    let cached_hit = match cached_scope {
      Some(scope) =>
        cached_group_index == index &&
        scope.scope_name == data.scope_name &&
        scope.scope_version == data.scope_version
      None => false
    }
    let scope_group : ScopeGroup? = if cached_hit {
      cached_scope
    } else {
      find_scope_group(target, data.scope_name, data.scope_version)
    }
    match scope_group {
      Some(scope) => {
        scope.spans.push(data)
        scope.size_hint = scope.size_hint + span_hint
        cached_scope = Some(scope)
        cached_group_index = index
      }
      None => {
        let spans_for_scope : Array[@sdk.SpanData] = [data]
        let created : ScopeGroup = {
          scope_name: data.scope_name,
          scope_version: data.scope_version,
          spans: spans_for_scope,
          size_hint: span_hint,
        }
        target.scopes.push(created)
        match target.scope_index {
          Some(scope_index) =>
            scope_index.set(
              (created.scope_name, created.scope_version),
              target.scopes.length() - 1,
            )
          None => ()
        }
        cached_scope = Some(created)
        cached_group_index = index
      }
    }
    target.size_hint = target.size_hint + span_hint
  }
  groups
}

// Estimate encoded size of resource attributes and of a scope group's
// name/version plus span payloads.

///|
fn resource_size_hint(resource : Map[String, @sdk.AttributeValue]) -> Int32 {
  16 + resource.length() * 48
}

///|
fn scope_size_hint(scope : ScopeGroup) -> Int32 {
  32 +
  scope.scope_name.length() +
  scope.scope_version.length() +
  scope.size_hint
}

// Encode spans as an `ExportTraceServiceRequest` protobuf message.

///|
pub fn encode_trace_request(spans : Array[@sdk.SpanData]) -> Bytes {
  if spans.length() == 0 {
    return b""
  }
  // Group the spans by resource and scope before encoding.
  let groups = group_spans(spans)
  let mut total_hint = 32
  for group in groups {
    total_hint = total_hint + 32 + resource_size_hint(group.resource)
    for scope in group.scopes {
      total_hint = total_hint + scope_size_hint(scope)
    }
  }
  let writer = take_root_writer(total_hint)
  for group in groups {
    let mut scopes_hint = 0
    for scope in group.scopes {
      scopes_hint = scopes_hint + scope_size_hint(scope)
    }
    let resource_spans = writer.take_scratch_with_capacity(
      32 + resource_size_hint(group.resource) + scopes_hint,
    )
    encode_resource(resource_spans, group.resource)
    for scope in group.scopes {
      let scope_spans = resource_spans.take_scratch_with_capacity(
        32 + scope_size_hint(scope),
      )
      encode_scope(scope_spans, scope.scope_name, scope.scope_version)
      for span in scope.spans {
        encode_span(scope_spans, span)
      }
      resource_spans.append_message(2, scope_spans)
    }
    writer.append_message(1, resource_spans)
  }
  let bytes = writer.to_bytes()
  release_root_writer(writer)
  bytes
}
