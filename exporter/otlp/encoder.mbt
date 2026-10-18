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
fn write_scalar_attribute_header(
  writer : ProtoWriter,
  field : Int,
  key_len : Int,
  any_size : Int,
) -> Unit {
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
fn try_encode_scalar_attribute(
  writer : ProtoWriter,
  field : Int,
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
      writer.write_tag(2, 2)
      writer.write_varint(any_size.to_uint64())
      writer.write_tag(1, 2)
      writer.write_varint(value_len.to_uint64())
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
      writer.write_tag(2, 2)
      writer.write_varint(2)
      writer.write_bool_field(2, flag)
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
      writer.write_tag(2, 2)
      writer.write_varint(any_size.to_uint64())
      writer.write_varint_field(3, bits)
      true
    }
    @sdk.DoubleValue(number) => {
      write_scalar_attribute_header(writer, field, key_len, 9)
      if !writer.try_write_ascii_raw(key) {
        writer.len = mark
        return false
      }
      writer.write_tag(2, 2)
      writer.write_varint(9)
      writer.write_fixed64_field(4, number.reinterpret_as_uint64())
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
fn write_decimal(sb : StringBuilder, value : Int) -> Unit {
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
  mut size_hint : Int
}

///|
priv struct ResourceGroup {
  resource : Map[String, @sdk.AttributeValue]
  scopes : Array[ScopeGroup]
  mut size_hint : Int
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
  for scope in group.scopes {
    if scope.scope_name == scope_name && scope.scope_version == scope_version {
      return Some(scope)
    }
  }
  None
}

// Rough encoded size of one span, used to size the scratch buffers. Attribute
// values are approximated by their count; for spans with very long values the
// estimate may be too small.
///|
fn estimate_span_size(data : @sdk.SpanData) -> Int {
  let mut size = 96 + data.name.length() + data.attributes.length() * 40
  for event in data.events {
    size = size + 64 + event.name.length() + event.attributes.length() * 40
  }
  for link in data.links {
    size = size + 64 + link.attributes.length() * 40
  }
  size
}

///|
fn group_spans(spans : Array[@sdk.SpanData]) -> Array[ResourceGroup] {
  let groups : Array[ResourceGroup] = []
  let mut resource_index : Map[String, Int32]? = None
  let mut last_resource : Map[String, @sdk.AttributeValue]? = None
  // Index of the group for `last_resource`.
  let mut last_index = -1
  // Canonical key of `groups[last_index]` when it has already been computed.
  let mut last_resource_key : String? = None
  // Whether the key of `groups[last_index]` has not been registered in
  // `resource_index` yet.
  let mut unindexed = false
  // Scope group of the last matched span.
  let mut cached_group_index = -1
  let mut cached_scope : ScopeGroup? = None
  for data in spans {
    let index = match last_resource {
      Some(resource) if physical_equal(resource, data.resource) => last_index
      _ => {
        if unindexed {
          let index_map : Map[String, Int32] = match resource_index {
            Some(map) => map
            None => {
              let map : Map[String, Int32] = Map([])
              resource_index = Some(map)
              map
            }
          }
          let key = match last_resource_key {
            Some(key) => key
            None => resource_key(groups[last_index].resource)
          }
          index_map.set(key, last_index)
          unindexed = false
        }
        let resolved = match last_resource {
          None => {
            let created : ResourceGroup = {
              resource: data.resource,
              scopes: [],
              size_hint: 0,
            }
            groups.push(created)
            unindexed = true
            last_resource_key = None
            groups.length() - 1
          }
          Some(_) => {
            let key = resource_key(data.resource)
            let known : Int32? = match resource_index {
              Some(map) => map.get(key)
              None => None
            }
            match known {
              Some(index) => index
              None => {
                let created : ResourceGroup = {
                  resource: data.resource,
                  scopes: [],
                  size_hint: 0,
                }
                groups.push(created)
                unindexed = true
                last_resource_key = Some(key)
                groups.length() - 1
              }
            }
          }
        }
        last_resource = Some(data.resource)
        last_index = resolved
        resolved
      }
    }
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
        cached_scope = Some(created)
        cached_group_index = index
      }
    }
    target.size_hint = target.size_hint + span_hint
  }
  groups
}

// If every span shares the same resource (by reference) and the same scope
// name and version, returning the total estimated encoded span size. The batch
// can then be encoded as one ResourceSpans with one ScopeSpans.
///|
fn uniform_batch_size_hint(spans : Array[@sdk.SpanData]) -> Int? {
  let len = spans.length()
  if len == 0 {
    return None
  }
  let first = spans.unsafe_get(0)
  let mut hint = estimate_span_size(first)
  let mut i = 1
  while i < len {
    let data = spans.unsafe_get(i)
    if !physical_equal(data.resource, first.resource) ||
      data.scope_name != first.scope_name ||
      data.scope_version != first.scope_version {
      return None
    }
    hint = hint + estimate_span_size(data)
    i = i + 1
  }
  Some(hint)
}

// Estimate encoded size of resource attributes and of a scope group's
// name/version plus span payloads.
///|
fn resource_size_hint(resource : Map[String, @sdk.AttributeValue]) -> Int {
  16 + resource.length() * 48
}

///|
fn scope_size_hint(scope : ScopeGroup) -> Int {
  32 + scope.scope_name.length() + scope.scope_version.length() + scope.size_hint
}

// Encode spans as an `ExportTraceServiceRequest` protobuf message.

///|
pub fn encode_trace_request(spans : Array[@sdk.SpanData]) -> Bytes {
  if spans.length() == 0 {
    return b""
  }
  match uniform_batch_size_hint(spans) {
    Some(span_hint) => {
      let first = spans.unsafe_get(0)
      let scope_hint = 32 +
        first.scope_name.length() +
        first.scope_version.length()
      let scope_spans_hint = scope_hint + span_hint
      let resource_spans_hint = resource_size_hint(first.resource) +
        scope_spans_hint
      let writer = ProtoWriter::with_capacity(32 + resource_spans_hint)
      let resource_spans = writer.take_scratch_with_capacity(
        32 + resource_spans_hint,
      )
      encode_resource(resource_spans, first.resource)
      let scope_spans = resource_spans.take_scratch_with_capacity(
        32 + scope_spans_hint,
      )
      encode_scope(scope_spans, first.scope_name, first.scope_version)
      for span in spans {
        encode_span(scope_spans, span)
      }
      resource_spans.append_message(2, scope_spans)
      writer.append_message(1, resource_spans)
      writer.to_bytes()
    }
    None => {
      let groups = group_spans(spans)
      let mut total_hint = 32
      for group in groups {
        total_hint = total_hint + 32 + resource_size_hint(group.resource)
        for scope in group.scopes {
          total_hint = total_hint + scope_size_hint(scope)
        }
      }
      let writer = ProtoWriter::with_capacity(total_hint)
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
      writer.to_bytes()
    }
  }
}
