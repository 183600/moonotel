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

// Byte length of `text` once encoded as UTF-8.

///|
fn utf8_length(text : String) -> Int32 {
  let len = text.length()
  // Fast path: pure-ASCII text has one UTF-8 byte per UTF-16 code unit.
  let mut i = 0
  while i < len {
    if text.unsafe_get(i).to_int() >= 0x80 {
      break
    }
    i = i + 1
  }
  if i == len {
    return len
  }
  // Count the UTF-8 bytes directly. Surrogates count two bytes each, so a
  // valid surrogate pair counts four, matching `@utf8.encode`.
  let mut bytes = i
  while i < len {
    let code = text.unsafe_get(i).to_int()
    if code < 0x80 {
      bytes = bytes + 1
    } else if code < 0x800 {
      bytes = bytes + 2
    } else if code >= 0xD800 && code <= 0xDFFF {
      bytes = bytes + 2
    } else {
      bytes = bytes + 3
    }
    i = i + 1
  }
  bytes
}

// Exact encoded size of the scalar `AnyValue` forms.

///|
fn scalar_any_value_size(value : @sdk.AttributeValue) -> Int32 {
  match value {
    @sdk.StringValue(text) => {
      let n = utf8_length(text)
      1 + varint_size(n.to_uint64()) + n
    }
    @sdk.BoolValue(_) => 2
    @sdk.IntValue(number) => 1 + varint_size(number.reinterpret_as_uint64())
    @sdk.DoubleValue(_) => 9
    @sdk.StringArrayValue(_) => 0
    @sdk.BoolArrayValue(_) => 0
    @sdk.IntArrayValue(_) => 0
    @sdk.DoubleArrayValue(_) => 0
  }
}

// Whether the value is an array.

///|
fn is_array_value(value : @sdk.AttributeValue) -> Bool {
  match value {
    @sdk.StringValue(_)
    | @sdk.BoolValue(_)
    | @sdk.IntValue(_)
    | @sdk.DoubleValue(_) => false
    @sdk.StringArrayValue(_)
    | @sdk.BoolArrayValue(_)
    | @sdk.IntArrayValue(_)
    | @sdk.DoubleArrayValue(_) => true
  }
}

// Write the body of a scalar `AnyValue` (without its enclosing length prefix).

///|
fn encode_scalar_any_value(
  writer : ProtoWriter,
  value : @sdk.AttributeValue,
) -> Unit {
  match value {
    @sdk.StringValue(text) => writer.write_string_field(1, text)
    @sdk.BoolValue(flag) => writer.write_bool_field(2, flag)
    @sdk.IntValue(number) =>
      writer.write_varint_field(3, number.reinterpret_as_uint64())
    @sdk.DoubleValue(number) => writer.write_double_field(4, number)
    @sdk.StringArrayValue(_) => ()
    @sdk.BoolArrayValue(_) => ()
    @sdk.IntArrayValue(_) => ()
    @sdk.DoubleArrayValue(_) => ()
  }
}

///|
fn encode_attributes(
  writer : ProtoWriter,
  field : Int32,
  attributes : Map[String, @sdk.AttributeValue],
) -> Unit {
  for entry in attributes.iter() {
    let (key, value) = entry
    let kv = writer.take_scratch()
    kv.write_string_field(1, key)
    if is_array_value(value) {
      let any_value = kv.take_scratch()
      encode_any_value(any_value, value)
      kv.append_message(2, any_value)
    } else {
      kv.write_tag(2, 2)
      kv.write_varint(scalar_any_value_size(value).to_uint64())
      encode_scalar_any_value(kv, value)
    }
    writer.append_message(field, kv)
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

// Canonical key for grouping spans that share a resource.

///|
fn resource_key_value(value : @sdk.AttributeValue) -> String {
  match value {
    @sdk.StringValue(text) => "s" + text.length().to_string() + ":" + text
    @sdk.BoolValue(flag) => if flag { "b1" } else { "b0" }
    @sdk.IntValue(number) => "i" + number.to_string() + ";"
    @sdk.DoubleValue(number) =>
      "d" + number.reinterpret_as_uint64().to_string() + ";"
    @sdk.StringArrayValue(items) => {
      let sb = StringBuilder()
      sb.write_char('a')
      sb.write_string(items.length().to_string())
      sb.write_char(':')
      for item in items {
        sb.write_string(item.length().to_string())
        sb.write_char(':')
        sb.write_string(item)
      }
      sb.to_string()
    }
    @sdk.BoolArrayValue(items) => {
      let sb = StringBuilder()
      sb.write_string("ab")
      sb.write_string(items.length().to_string())
      sb.write_char(':')
      for item in items {
        sb.write_char(if item { '1' } else { '0' })
      }
      sb.to_string()
    }
    @sdk.IntArrayValue(items) => {
      let sb = StringBuilder()
      sb.write_string("ai")
      for item in items {
        sb.write_string(item.to_string())
        sb.write_char(';')
      }
      sb.to_string()
    }
    @sdk.DoubleArrayValue(items) => {
      let sb = StringBuilder()
      sb.write_string("ad")
      for item in items {
        sb.write_string(item.reinterpret_as_uint64().to_string())
        sb.write_char(';')
      }
      sb.to_string()
    }
  }
}

///|
fn resource_key(resource : Map[String, @sdk.AttributeValue]) -> String {
  let keys : Array[String] = []
  for entry in resource.iter() {
    keys.push(entry.0)
  }
  keys.sort()
  let sb = StringBuilder()
  for key in keys {
    let value_text = match resource.get(key) {
      Some(value) => resource_key_value(value)
      None => ""
    }
    sb.write_string(key.length().to_string())
    sb.write_char(':')
    sb.write_string(key)
    sb.write_char('=')
    sb.write_string(value_text)
  }
  sb.to_string()
}

///|
priv struct ScopeGroup {
  scope_name : String
  scope_version : String
  spans : Array[@sdk.SpanData]
}

///|
priv struct ResourceGroup {
  resource : Map[String, @sdk.AttributeValue]
  scopes : Array[ScopeGroup]
}

///|
fn group_spans(spans : Array[@sdk.SpanData]) -> Array[ResourceGroup] {
  let groups : Array[ResourceGroup] = []
  let resource_index : Map[String, Int32] = Map([])
  let mut last_resource : Map[String, @sdk.AttributeValue]? = None
  // Index of the group for `last_resource`.
  let mut last_index = -1
  // Whether the key of `groups[last_index]` has not been registered in
  // `resource_index` yet. Batches commonly contain a single resource, in which
  // case the (comparatively expensive) key is never needed.
  let mut unindexed = false
  for data in spans {
    let index = match last_resource {
      Some(resource) if physical_equal(resource, data.resource) => last_index
      _ => {
        if unindexed {
          resource_index.set(resource_key(groups[last_index].resource), last_index)
          unindexed = false
        }
        let key = resource_key(data.resource)
        last_resource = Some(data.resource)
        let resolved = match resource_index.get(key) {
          Some(index) => index
          None => {
            let created : ResourceGroup = {
              resource: data.resource,
              scopes: [],
            }
            groups.push(created)
            unindexed = true
            groups.length() - 1
          }
        }
        last_index = resolved
        resolved
      }
    }
    let target = groups[index]
    let mut scope_group : ScopeGroup? = None
    for scope in target.scopes {
      if scope.scope_name == data.scope_name &&
        scope.scope_version == data.scope_version {
        scope_group = Some(scope)
        // Scope groups are unique per resource group, so the first match is
        // the only match.
        break
      }
    }
    match scope_group {
      Some(scope) => scope.spans.push(data)
      None => {
        let spans_for_scope : Array[@sdk.SpanData] = [data]
        target.scopes.push({
          scope_name: data.scope_name,
          scope_version: data.scope_version,
          spans: spans_for_scope,
        })
      }
    }
  }
  groups
}

// Encode spans as an `ExportTraceServiceRequest` protobuf message.

///|
pub fn encode_trace_request(spans : Array[@sdk.SpanData]) -> Bytes {
  // Initial capacity estimate: 160 bytes per span plus the message header.
  let writer = ProtoWriter::with_capacity(64 + spans.length() * 160)
  for group in group_spans(spans) {
    let resource_spans = writer.take_scratch()
    encode_resource(resource_spans, group.resource)
    for scope in group.scopes {
      let scope_spans = resource_spans.take_scratch()
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
