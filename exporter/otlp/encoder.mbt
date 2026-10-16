// Encodes SDK SpanData into an OTLP `ExportTraceServiceRequest` protobuf
// message (opentelemetry-proto v1 trace service).

fn encode_any_value(writer : ProtoWriter, value : @sdk.AttributeValue) -> Unit {
  match value {
    @sdk.StringValue(text) => writer.write_string_field(1, text)
    @sdk.BoolValue(flag) => writer.write_bool_field(2, flag)
    @sdk.IntValue(number) => writer.write_varint_field(3, number.reinterpret_as_uint64())
    @sdk.DoubleValue(number) => writer.write_double_field(4, number)
    @sdk.StringArrayValue(items) => {
      let array = writer.take_scratch()
      for item in items {
        let element = array.take_scratch()
        element.write_string_field(1, item)
        array.append_message(1, element)
      }
      writer.append_message(5, array)
    }
  }
}

fn encode_attributes(
  writer : ProtoWriter,
  field : Int,
  attributes : Map[String, @sdk.AttributeValue]
) -> Unit {
  attributes.each(fn(key, value) {
    let kv = writer.take_scratch()
    kv.write_string_field(1, key)
    let any_value = kv.take_scratch()
    encode_any_value(any_value, value)
    kv.append_message(2, any_value)
    writer.append_message(field, kv)
  })
}

fn encode_resource(writer : ProtoWriter, resource : Map[String, @sdk.AttributeValue]) -> Unit {
  let resource_writer = writer.take_scratch()
  encode_attributes(resource_writer, 1, resource)
  writer.append_message(1, resource_writer)
}

fn encode_scope(writer : ProtoWriter, name : String, version : String) -> Unit {
  let scope = writer.take_scratch()
  scope.write_string_field(1, name)
  if version != "" {
    scope.write_string_field(2, version)
  }
  writer.append_message(1, scope)
}

fn encode_event(writer : ProtoWriter, event : @sdk.SpanEvent) -> Unit {
  let event_writer = writer.take_scratch()
  event_writer.write_fixed64_field(1, event.time_unix_nano.reinterpret_as_uint64())
  event_writer.write_string_field(2, event.name)
  encode_attributes(event_writer, 3, event.attributes)
  writer.append_message(11, event_writer)
}

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

fn encode_span(writer : ProtoWriter, data : @sdk.SpanData) -> Unit {
  let span = writer.take_scratch()
  span.write_bytes_from_int_array(1, data.span_context.trace_id_view())
  span.write_bytes_from_int_array(2, data.span_context.span_id_view())
  if data.parent_span_id.length() > 0 {
    span.write_bytes_from_int_array(4, data.parent_span_id)
  }
  span.write_string_field(5, data.name)
  span.write_varint_field(6, data.kind.otlp_value().to_uint64())
  span.write_fixed64_field(7, data.start_time_unix_nano.reinterpret_as_uint64())
  span.write_fixed64_field(8, data.end_time_unix_nano.reinterpret_as_uint64())
  encode_attributes(span, 9, data.attributes)
  for event in data.events {
    encode_event(span, event)
  }
  encode_status(span, data)
  span.write_fixed32_field(
    16,
    data.span_context.trace_flags().reinterpret_as_uint(),
  )
  writer.append_message(2, span)
}

// Canonical key for grouping spans that share a resource.
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
  }
}

fn resource_key(resource : Map[String, @sdk.AttributeValue]) -> String {
  let keys : Array[String] = []
  resource.each(fn(key, _value) { keys.push(key) })
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

priv struct ScopeGroup {
  scope_name : String
  scope_version : String
  spans : Array[@sdk.SpanData]
}

priv struct ResourceGroup {
  resource : Map[String, @sdk.AttributeValue]
  scopes : Array[ScopeGroup]
}

fn group_spans(spans : Array[@sdk.SpanData]) -> Array[ResourceGroup] {
  let groups : Array[ResourceGroup] = []
  let resource_index : Map[String, Int] = Map([])
  let mut last_resource : Map[String, @sdk.AttributeValue]? = None
  // Index of the group for `last_resource`; spans from the same producer
  // usually share one resource object, so the hash lookup is skipped for all
  // but the first span of each run.
  let mut last_index = -1
  for data in spans {
    let index = match last_resource {
      Some(resource) if physical_equal(resource, data.resource) => last_index
      _ => {
        let key = resource_key(data.resource)
        last_resource = Some(data.resource)
        let resolved = match resource_index.get(key) {
          Some(index) => index
          None => {
            let created : ResourceGroup = { resource: data.resource, scopes: [] }
            resource_index.set(key, groups.length())
            groups.push(created)
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
      if scope.scope_name == data.scope_name && scope.scope_version == data.scope_version {
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
pub fn encode_trace_request(spans : Array[@sdk.SpanData]) -> Bytes {
  let writer = ProtoWriter::with_capacity(64 + spans.length() * 128)
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
