// Blackbox tests for the OTLP protobuf encoder.
//
// These tests decode the produced `ExportTraceServiceRequest` with a minimal
// protobuf reader and assert on the wire content.

///|
struct Field {
  number : Int32
  wire : Int32
  varint : UInt64
  payload : BytesView
}

///|
fn read_varint(data : BytesView, offset : Int32) -> (UInt64, Int32) {
  let mut result : UInt64 = 0
  let mut shift = 0
  let mut pos = offset
  let mut done = false
  while !done {
    let byte = data.at(pos).to_int() & 0xFF
    result = result | ((byte & 0x7F).to_uint64() << shift)
    pos = pos + 1
    if byte < 0x80 {
      done = true
    } else {
      shift = shift + 7
    }
  }
  (result, pos)
}

///|
fn parse_fields(data : BytesView) -> Array[Field] {
  let fields : Array[Field] = []
  let length = data.length()
  let mut pos = 0
  while pos < length {
    let (tag, after_tag) = read_varint(data, pos)
    pos = after_tag
    let number = (tag >> 3).to_int()
    let wire = (tag & 7).to_int()
    if wire == 0 {
      let (value, after) = read_varint(data, pos)
      pos = after
      fields.push({
        number,
        wire,
        varint: value,
        payload: data.exact_view(start=0, end=0),
      })
    } else if wire == 1 {
      fields.push({
        number,
        wire,
        varint: 0,
        payload: data.exact_view(start=pos, end=pos + 8),
      })
      pos = pos + 8
    } else if wire == 2 {
      let (len, after) = read_varint(data, pos)
      let size = len.to_int()
      fields.push({
        number,
        wire,
        varint: 0,
        payload: data.exact_view(start=after, end=after + size),
      })
      pos = after + size
    } else if wire == 5 {
      fields.push({
        number,
        wire,
        varint: 0,
        payload: data.exact_view(start=pos, end=pos + 4),
      })
      pos = pos + 4
    } else {
      break
    }
  }
  fields
}

///|
fn fields_of(fields : Array[Field], number : Int32) -> Array[Field] {
  let out : Array[Field] = []
  for field in fields {
    if field.number == number {
      out.push(field)
    }
  }
  out
}

///|
fn first_of(fields : Array[Field], number : Int32) -> Field? {
  for field in fields {
    if field.number == number {
      return Some(field)
    }
  }
  None
}

///|
fn fixed64_value(payload : BytesView) -> UInt64 {
  let mut value : UInt64 = 0
  for i = 0; i < 8; i = i + 1 {
    value = value | ((payload.at(i).to_int() & 0xFF).to_uint64() << (8 * i))
  }
  value
}

///|
fn attribute_value(span_fields : Array[Field], key : String) -> String? {
  for attribute in fields_of(span_fields, 9) {
    let kv = parse_fields(attribute.payload)
    let kv_key = match first_of(kv, 1) {
      Some(field) => field.payload |> @utf8.decode_lossy
      None => ""
    }
    if kv_key == key {
      match first_of(kv, 2) {
        Some(any) => {
          let any_fields = parse_fields(any.payload)
          return match first_of(any_fields, 1) {
            Some(text) => Some(text.payload |> @utf8.decode_lossy)
            None => None
          }
        }
        None => return None
      }
    }
  }
  None
}

///|
fn sample_span() -> @sdk.SpanData {
  let attributes : Map[String, @sdk.AttributeValue] = Map([], capacity=1)
  attributes.set("http.request.method", @sdk.StringValue("GET"))
  attributes.set("http.response.status_code", @sdk.IntValue(200L))
  let resource : Map[String, @sdk.AttributeValue] = Map([], capacity=1)
  resource.set(@sdk.SERVICE_NAME, @sdk.StringValue("encoder-test"))
  {
    name: "GET /users",
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: @api.bytes_from_hex("1122334455667788").unwrap(),
    kind: @api.SpanKind::Server,
    start_time_unix_nano: 1600000000000000000L,
    end_time_unix_nano: 1600000000500000000L,
    attributes,
    events: [
      {
        name: "retry",
        time_unix_nano: 1600000000250000000L,
        attributes: Map([], capacity=1),
        dropped_attributes_count: 0,
      },
    ],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Ok,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(resource),
    scope_name: "encoder-scope",
    scope_version: "1.2.3",
  }
}

///|
test "encode_trace_request_span_fields" {
  let encoded = @otlp.encode_trace_request([sample_span()])
  let request = parse_fields(encoded.exact_view())
  let resource_spans = fields_of(request, 1)
  assert_eq(resource_spans.length(), 1)
  let resource_spans_fields = parse_fields(resource_spans[0].payload)
  let resource = first_of(resource_spans_fields, 1).unwrap()
  let resource_fields = parse_fields(resource.payload)
  let resource_attributes = fields_of(resource_fields, 1)
  assert_eq(resource_attributes.length(), 1)
  let resource_kv = parse_fields(resource_attributes[0].payload)
  assert_eq(
    first_of(resource_kv, 1).unwrap().payload |> @utf8.decode_lossy,
    "service.name",
  )
  let scope_spans = first_of(resource_spans_fields, 2).unwrap()
  let scope_spans_fields = parse_fields(scope_spans.payload)
  let scope = first_of(scope_spans_fields, 1).unwrap()
  let scope_fields = parse_fields(scope.payload)
  assert_eq(
    first_of(scope_fields, 1).unwrap().payload |> @utf8.decode_lossy,
    "encoder-scope",
  )
  assert_eq(
    first_of(scope_fields, 2).unwrap().payload |> @utf8.decode_lossy,
    "1.2.3",
  )
  let spans = fields_of(scope_spans_fields, 2)
  assert_eq(spans.length(), 1)
  let span = parse_fields(spans[0].payload)
  assert_eq(
    @api.bytes_to_hex(
      first_of(span, 1).unwrap().payload.to_array().map(byte_to_int),
    ),
    "4bf92f359d1e75b7618a2d1f3c4e5a6b",
  )
  assert_eq(
    @api.bytes_to_hex(
      first_of(span, 2).unwrap().payload.to_array().map(byte_to_int),
    ),
    "00f067aa0ba902b7",
  )
  assert_eq(
    @api.bytes_to_hex(
      first_of(span, 4).unwrap().payload.to_array().map(byte_to_int),
    ),
    "1122334455667788",
  )
  assert_eq(
    first_of(span, 5).unwrap().payload |> @utf8.decode_lossy,
    "GET /users",
  )
  assert_eq(first_of(span, 6).unwrap().varint, 2)
  assert_eq(
    fixed64_value(first_of(span, 7).unwrap().payload).reinterpret_as_int64(),
    1600000000000000000L,
  )
  assert_eq(
    fixed64_value(first_of(span, 8).unwrap().payload).reinterpret_as_int64(),
    1600000000500000000L,
  )
  assert_eq(attribute_value(span, "http.request.method"), Some("GET"))
  let status = first_of(span, 15).unwrap()
  let status_fields = parse_fields(status.payload)
  assert_eq(first_of(status_fields, 3).unwrap().varint, 1)
  let events = fields_of(span, 11)
  assert_eq(events.length(), 1)
  let event_fields = parse_fields(events[0].payload)
  assert_eq(
    first_of(event_fields, 2).unwrap().payload |> @utf8.decode_lossy,
    "retry",
  )
}

///|
fn byte_to_int(value : Byte) -> Int32 {
  value.to_int() & 0xFF
}

///|
test "encode_trace_request_empty" {
  assert_eq(@otlp.encode_trace_request([]).length(), 0)
}

///|
test "encode_trace_request_groups_scopes" {
  let first = sample_span()
  let second = sample_span()
  let encoded = @otlp.encode_trace_request([first, second])
  let request = parse_fields(encoded.exact_view())
  let resource_spans = fields_of(request, 1)
  assert_eq(resource_spans.length(), 1)
  let scope_spans = fields_of(parse_fields(resource_spans[0].payload), 2)
  assert_eq(scope_spans.length(), 1)
  assert_eq(fields_of(parse_fields(scope_spans[0].payload), 2).length(), 2)
}

///|
test "encode_root_span_omits_parent" {
  let span = sample_span()
  let root : @sdk.SpanData = { ..span, parent_span_id: [], }
  let encoded = @otlp.encode_trace_request([root])
  let request = parse_fields(encoded.exact_view())
  let resource_spans = parse_fields(fields_of(request, 1)[0].payload)
  let scope_spans = parse_fields(first_of(resource_spans, 2).unwrap().payload)
  let span_fields = parse_fields(first_of(scope_spans, 2).unwrap().payload)
  assert_true(first_of(span_fields, 4) is None)
}

///|
fn span_field_text(span : @sdk.SpanData, number : Int32) -> String? {
  let encoded = @otlp.encode_trace_request([span])
  let request = parse_fields(encoded.exact_view())
  let resource_spans = parse_fields(fields_of(request, 1)[0].payload)
  let scope_spans = parse_fields(first_of(resource_spans, 2).unwrap().payload)
  let span_fields = parse_fields(first_of(scope_spans, 2).unwrap().payload)
  match first_of(span_fields, number) {
    Some(field) => Some(field.payload |> @utf8.decode_lossy)
    None => None
  }
}

///|
test "encode_span_writes_trace_state" {
  let span = sample_span()
  let with_state : @sdk.SpanData = {
    ..span,
    span_context: span.span_context.with_tracestate(
      "congo=t61rcWkgMzE,vendor=1",
    ),
  }
  assert_eq(span_field_text(with_state, 3), Some("congo=t61rcWkgMzE,vendor=1"))
  assert_true(span_field_text(span, 3) is None)
}

///|
test "encode_span_writes_dropped_counts" {
  let event : @sdk.SpanEvent = {
    name: "ev",
    time_unix_nano: 5L,
    attributes: Map([]),
    dropped_attributes_count: 6,
  }
  let link : @sdk.SpanLink = {
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("1122334455667788").unwrap(),
      @api.TRACE_FLAGS_SAMPLED,
    ),
    attributes: Map([]),
    dropped_attributes_count: 7,
  }
  let span : @sdk.SpanData = {
    ..sample_span(),
    events: [event],
    links: [link],
    dropped_attributes_count: 3,
    dropped_events_count: 4,
    dropped_links_count: 5,
  }
  let span_fields = link_test_span_fields(span)
  assert_eq(first_of(span_fields, 10).unwrap().varint, 3)
  assert_eq(first_of(span_fields, 12).unwrap().varint, 4)
  assert_eq(first_of(span_fields, 14).unwrap().varint, 5)
  let event_fields = parse_fields(fields_of(span_fields, 11)[0].payload)
  assert_eq(first_of(event_fields, 4).unwrap().varint, 6)
  let link_fields = parse_fields(fields_of(span_fields, 13)[0].payload)
  assert_eq(first_of(link_fields, 5).unwrap().varint, 7)
}

///|
test "encode_span_omits_zero_dropped_counts" {
  let span_fields = link_test_span_fields(sample_span())
  assert_true(first_of(span_fields, 10) is None)
  assert_true(first_of(span_fields, 12) is None)
  assert_true(first_of(span_fields, 14) is None)
  let event_fields = parse_fields(fields_of(span_fields, 11)[0].payload)
  assert_true(first_of(event_fields, 4) is None)
}
