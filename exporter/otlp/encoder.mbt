// Encodes SDK SpanData into an OTLP `ExportTraceServiceRequest` protobuf
// message (opentelemetry-proto v1 trace service).

fn encode_any_value(writer : ProtoWriter, value : @sdk.AttributeValue) -> Unit {
  match value {
    @sdk.StringValue(text) => writer.write_string_field(1, text)
    @sdk.BoolValue(flag) => writer.write_bool_field(2, flag)
    @sdk.IntValue(number) => writer.write_varint_field(3, number.reinterpret_as_uint64())
    @sdk.DoubleValue(number) => writer.write_double_field(4, number)
    @sdk.StringArrayValue(items) =>
      writer.write_message_field(5, fn(inner) {
        for item in items {
          inner.write_message_field(1, fn(element) {
            element.write_string_field(1, item)
          })
        }
      })
  }
}

fn encode_attributes(
  writer : ProtoWriter,
  field : Int,
  attributes : Map[String, @sdk.AttributeValue]
) -> Unit {
  attributes.each(fn(key, value) {
    writer.write_message_field(field, fn(kv) {
      kv.write_string_field(1, key)
      kv.write_message_field(2, fn(any_value) {
        encode_any_value(any_value, value)
      })
    })
  })
}

fn encode_resource(writer : ProtoWriter, resource : Map[String, @sdk.AttributeValue]) -> Unit {
  writer.write_message_field(1, fn(resource_writer) {
    encode_attributes(resource_writer, 1, resource)
  })
}

fn encode_scope(writer : ProtoWriter, name : String, version : String) -> Unit {
  writer.write_message_field(1, fn(scope) {
    scope.write_string_field(1, name)
    if version != "" {
      scope.write_string_field(2, version)
    }
  })
}

fn encode_event(writer : ProtoWriter, event : @sdk.SpanEvent) -> Unit {
  writer.write_message_field(11, fn(event_writer) {
    event_writer.write_fixed64_field(1, event.time_unix_nano.reinterpret_as_uint64())
    event_writer.write_string_field(2, event.name)
    encode_attributes(event_writer, 3, event.attributes)
  })
}

fn encode_status(writer : ProtoWriter, data : @sdk.SpanData) -> Unit {
  if data.status != @api.StatusCode::Unset || data.status_description != "" {
    writer.write_message_field(15, fn(status) {
      if data.status_description != "" {
        status.write_string_field(2, data.status_description)
      }
      let code = data.status.otlp_value()
      if code != 0 {
        status.write_varint_field(3, code.to_uint64())
      }
    })
  }
}

fn encode_span(writer : ProtoWriter, data : @sdk.SpanData) -> Unit {
  writer.write_message_field(2, fn(span) {
    span.write_bytes_field(1, bytes_from_bytes_array(data.span_context.trace_id()))
    span.write_bytes_field(2, bytes_from_bytes_array(data.span_context.span_id()))
    if data.parent_span_id.length() > 0 {
      span.write_bytes_field(4, bytes_from_bytes_array(data.parent_span_id))
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
    span.write_fixed32_field(16, data.span_context.trace_flags().to_uint())
  })
}

// Canonical key for grouping spans that share a resource.
fn resource_key(resource : Map[String, @sdk.AttributeValue]) -> String {
  let keys : Array[String] = []
  resource.each(fn(key, _value) { keys.push(key) })
  keys.sort()
  let parts : Array[String] = []
  for key in keys {
    let value_text = match resource.get(key) {
      Some(@sdk.StringValue(text)) => text
      Some(@sdk.BoolValue(flag)) => flag.to_string()
      Some(@sdk.IntValue(number)) => number.to_string()
      Some(@sdk.DoubleValue(number)) => number.to_string()
      Some(@sdk.StringArrayValue(items)) => items.join(",")
      None => ""
    }
    parts.push(key + "=" + value_text)
  }
  parts.join(";")
}

struct ScopeGroup {
  scope_name : String
  scope_version : String
  spans : Array[@sdk.SpanData]
}

struct ResourceGroup {
  key : String
  resource : Map[String, @sdk.AttributeValue]
  scopes : Array[ScopeGroup]
}

fn group_spans(spans : Array[@sdk.SpanData]) -> Array[ResourceGroup] {
  let groups : Array[ResourceGroup] = []
  for data in spans {
    let key = resource_key(data.resource)
    let mut resource_group : ResourceGroup? = None
    for group in groups {
      if group.key == key {
        resource_group = Some(group)
      }
    }
    let target = match resource_group {
      Some(group) => group
      None => {
        let created : ResourceGroup = { key, resource: data.resource, scopes: [] }
        groups.push(created)
        created
      }
    }
    let mut scope_group : ScopeGroup? = None
    for scope in target.scopes {
      if scope.scope_name == data.scope_name && scope.scope_version == data.scope_version {
        scope_group = Some(scope)
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
  let writer = ProtoWriter::new()
  for group in group_spans(spans) {
    writer.write_message_field(1, fn(resource_spans) {
      encode_resource(resource_spans, group.resource)
      for scope in group.scopes {
        resource_spans.write_message_field(2, fn(scope_spans) {
          encode_scope(scope_spans, scope.scope_name, scope.scope_version)
          for span in scope.spans {
            encode_span(scope_spans, span)
          }
        })
      }
    })
  }
  writer.to_bytes()
}
