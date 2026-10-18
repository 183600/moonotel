// Tests for the OTLP/JSON trace request encoder. The encoded bytes are parsed
// back with the core JSON parser so that assertions exercise the document
// structure rather than incidental formatting.

///|
fn parse_json_text(text : String) -> Json {
  @json.parse(text) catch {
    err => abort("encoder produced invalid JSON: " + err.to_string())
  }
}

///|
fn json_member(value : Json, key : String) -> Json {
  match value {
    Object(object) =>
      match object.get(key) {
        Some(entry) => entry
        None => abort("missing JSON member: " + key)
      }
    _ => abort("expected a JSON object with member " + key)
  }
}

///|
fn json_has_member(value : Json, key : String) -> Bool {
  match value {
    Object(object) => object.get(key) is Some(_)
    _ => false
  }
}

///|
fn json_string_value(value : Json) -> String {
  match value {
    String(text) => text
    _ => abort("expected a JSON string")
  }
}

///|
fn json_number_value(value : Json) -> Double {
  match value {
    Number(number, ..) => number
    _ => abort("expected a JSON number")
  }
}

///|
fn json_bool_value(value : Json) -> Bool {
  match value {
    True => true
    False => false
    _ => abort("expected a JSON boolean")
  }
}

///|
fn json_array_value(value : Json) -> Array[Json] {
  match value {
    Array(items) => items
    _ => abort("expected a JSON array")
  }
}

///|
fn encode_json(spans : Array[@sdk.SpanData]) -> Json {
  parse_json_text(
    @utf8.decode_lossy(@otlp.encode_trace_request_json(spans)),
  )
}

///|
fn json_span_of(group : Json, index : Int) -> Json {
  let scope = json_array_value(json_member(group, "scopeSpans"))[0]
  json_array_value(json_member(scope, "spans"))[index]
}

///|
fn json_attribute(value : Json, key : String) -> Json? {
  for attribute in json_array_value(json_member(value, "attributes")) {
    if json_string_value(json_member(attribute, "key")) == key {
      return Some(json_member(attribute, "value"))
    }
  }
  None
}

///|
fn json_test_span() -> @sdk.SpanData {
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("http.method", @sdk.StringValue("GET"))
  attributes.set("attempt", @sdk.IntValue(42L))
  attributes.set("ratio", @sdk.DoubleValue(1.5))
  attributes.set("ok", @sdk.BoolValue(true))
  attributes.set("tags", @sdk.StringArrayValue(["a", "b"]))
  attributes.set("codes", @sdk.IntArrayValue([7L, 8L]))
  attributes.set("weights", @sdk.DoubleArrayValue([0.5, 0.25]))
  attributes.set("flags", @sdk.BoolArrayValue([true, false]))
  let event_attributes : Map[String, @sdk.AttributeValue] = Map([])
  event_attributes.set("exception.type", @sdk.StringValue("Boom"))
  let resource : Map[String, @sdk.AttributeValue] = Map([])
  resource.set(@sdk.SERVICE_NAME, @sdk.StringValue("json-encoder-test"))
  let link_context = @api.span_context(
    @api.bytes_from_hex("0af7651916cd43dd8448eb211c80319c").unwrap(),
    @api.bytes_from_hex("b7ad6b7169203331").unwrap(),
    0,
  )
  {
    name: "GET /v1/traces",
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
      tracestate="vendor=1",
    ),
    parent_span_id: @api.bytes_from_hex("1122334455667788").unwrap(),
    kind: @api.SpanKind::Client,
    start_time_unix_nano: 1000000000L,
    end_time_unix_nano: 2000000000L,
    attributes,
    events: [
      {
        name: "exception",
        time_unix_nano: 1500000000L,
        attributes: event_attributes,
        dropped_attributes_count: 0,
      },
    ],
    links: [@sdk.SpanLink::new(link_context)],
    dropped_attributes_count: 1,
    dropped_events_count: 2,
    dropped_links_count: 3,
    status: @api.StatusCode::Error,
    status_description: "boom",
    resource,
    scope_name: "otel-test",
    scope_version: "1.0.0",
  }
}

///|
test "json_encoder_empty_batch_is_empty" {
  assert_eq(@otlp.encode_trace_request_json([]).length(), 0)
}

///|
test "json_encoder_span_fields" {
  let root = encode_json([json_test_span()])
  let resource_spans = json_array_value(json_member(root, "resourceSpans"))
  assert_eq(resource_spans.length(), 1)
  let resource_attributes = json_attribute(
    json_member(resource_spans[0], "resource"),
    @sdk.SERVICE_NAME,
  ).unwrap()
  assert_eq(
    json_string_value(json_member(resource_attributes, "stringValue")),
    "json-encoder-test",
  )
  let scopes = json_array_value(json_member(resource_spans[0], "scopeSpans"))
  assert_eq(scopes.length(), 1)
  let scope = json_member(scopes[0], "scope")
  assert_eq(json_string_value(json_member(scope, "name")), "otel-test")
  assert_eq(json_string_value(json_member(scope, "version")), "1.0.0")
  let span = json_span_of(resource_spans[0], 0)
  assert_eq(
    json_string_value(json_member(span, "traceId")),
    "4bf92f359d1e75b7618a2d1f3c4e5a6b",
  )
  assert_eq(json_string_value(json_member(span, "spanId")), "00f067aa0ba902b7")
  assert_eq(
    json_string_value(json_member(span, "parentSpanId")),
    "1122334455667788",
  )
  assert_eq(json_string_value(json_member(span, "traceState")), "vendor=1")
  assert_eq(json_string_value(json_member(span, "name")), "GET /v1/traces")
  assert_eq(json_number_value(json_member(span, "kind")), 3.0)
  assert_eq(
    json_string_value(json_member(span, "startTimeUnixNano")),
    "1000000000",
  )
  assert_eq(
    json_string_value(json_member(span, "endTimeUnixNano")),
    "2000000000",
  )
  assert_eq(
    json_number_value(json_member(span, "droppedAttributesCount")),
    1.0,
  )
  assert_eq(json_number_value(json_member(span, "droppedEventsCount")), 2.0)
  assert_eq(json_number_value(json_member(span, "droppedLinksCount")), 3.0)
  assert_eq(json_number_value(json_member(span, "flags")), 1.0)
  let status = json_member(span, "status")
  assert_eq(json_string_value(json_member(status, "message")), "boom")
  assert_eq(json_number_value(json_member(status, "code")), 2.0)
}

///|
test "json_encoder_attribute_values" {
  let root = encode_json([json_test_span()])
  let span = json_span_of(
    json_array_value(json_member(root, "resourceSpans"))[0],
    0,
  )
  let attributes = json_array_value(json_member(span, "attributes"))
  assert_eq(attributes.length(), 8)
  let http_method = json_attribute(span, "http.method").unwrap()
  assert_eq(json_string_value(json_member(http_method, "stringValue")), "GET")
  let attempt = json_attribute(span, "attempt").unwrap()
  assert_eq(json_string_value(json_member(attempt, "intValue")), "42")
  let ratio = json_attribute(span, "ratio").unwrap()
  assert_eq(json_number_value(json_member(ratio, "doubleValue")), 1.5)
  let ok = json_attribute(span, "ok").unwrap()
  assert_true(json_bool_value(json_member(ok, "boolValue")))
  let tags = json_attribute(span, "tags").unwrap()
  let tag_values = json_array_value(
    json_member(json_member(tags, "arrayValue"), "values"),
  )
  assert_eq(tag_values.length(), 2)
  assert_eq(json_string_value(json_member(tag_values[1], "stringValue")), "b")
  let codes = json_attribute(span, "codes").unwrap()
  let code_values = json_array_value(
    json_member(json_member(codes, "arrayValue"), "values"),
  )
  assert_eq(json_string_value(json_member(code_values[0], "intValue")), "7")
  let weights = json_attribute(span, "weights").unwrap()
  let weight_values = json_array_value(
    json_member(json_member(weights, "arrayValue"), "values"),
  )
  assert_eq(
    json_number_value(json_member(weight_values[1], "doubleValue")),
    0.25,
  )
  let flags = json_attribute(span, "flags").unwrap()
  let flag_values = json_array_value(
    json_member(json_member(flags, "arrayValue"), "values"),
  )
  assert_false(json_bool_value(json_member(flag_values[1], "boolValue")))
}

///|
test "json_encoder_events_and_links" {
  let root = encode_json([json_test_span()])
  let span = json_span_of(
    json_array_value(json_member(root, "resourceSpans"))[0],
    0,
  )
  let events = json_array_value(json_member(span, "events"))
  assert_eq(events.length(), 1)
  assert_eq(json_string_value(json_member(events[0], "name")), "exception")
  assert_eq(
    json_string_value(json_member(events[0], "timeUnixNano")),
    "1500000000",
  )
  let event_type = json_attribute(events[0], "exception.type").unwrap()
  assert_eq(
    json_string_value(json_member(event_type, "stringValue")),
    "Boom",
  )
  let links = json_array_value(json_member(span, "links"))
  assert_eq(links.length(), 1)
  assert_eq(
    json_string_value(json_member(links[0], "traceId")),
    "0af7651916cd43dd8448eb211c80319c",
  )
  assert_eq(
    json_string_value(json_member(links[0], "spanId")),
    "b7ad6b7169203331",
  )
  assert_eq(json_number_value(json_member(links[0], "flags")), 0.0)
}

///|
test "json_encoder_omits_empty_optional_fields" {
  let minimal : @sdk.SpanData = {
    ..json_test_span(),
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      0,
    ),
    parent_span_id: [],
    attributes: Map([]),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
  }
  let root = encode_json([minimal])
  let span = json_span_of(
    json_array_value(json_member(root, "resourceSpans"))[0],
    0,
  )
  assert_false(json_has_member(span, "traceState"))
  assert_false(json_has_member(span, "parentSpanId"))
  assert_false(json_has_member(span, "attributes"))
  assert_false(json_has_member(span, "events"))
  assert_false(json_has_member(span, "links"))
  assert_false(json_has_member(span, "status"))
  assert_false(json_has_member(span, "droppedAttributesCount"))
  assert_eq(json_string_value(json_member(span, "name")), "GET /v1/traces")
}

///|
test "json_encoder_escapes_strings" {
  let name = "quote\" back\\ newline\n tab\t ctrl\u{0001} slash/ end"
  let span : @sdk.SpanData = { ..json_test_span(), name }
  let root = encode_json([span])
  let parsed = json_span_of(
    json_array_value(json_member(root, "resourceSpans"))[0],
    0,
  )
  assert_eq(json_string_value(json_member(parsed, "name")), name)
}

///|
test "json_encoder_writes_non_finite_doubles_as_strings" {
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set(
    "nan",
    @sdk.DoubleValue(0x7FF8000000000001L.reinterpret_as_double()),
  )
  attributes.set(
    "inf",
    @sdk.DoubleValue(0x7FF0000000000000L.reinterpret_as_double()),
  )
  attributes.set(
    "neg_inf",
    @sdk.DoubleValue(0xFFF0000000000000L.reinterpret_as_double()),
  )
  let span : @sdk.SpanData = { ..json_test_span(), attributes }
  let root = encode_json([span])
  let parsed = json_span_of(
    json_array_value(json_member(root, "resourceSpans"))[0],
    0,
  )
  assert_eq(
    json_string_value(
      json_member(json_attribute(parsed, "nan").unwrap(), "doubleValue"),
    ),
    "NaN",
  )
  assert_eq(
    json_string_value(
      json_member(json_attribute(parsed, "inf").unwrap(), "doubleValue"),
    ),
    "Infinity",
  )
  assert_eq(
    json_string_value(
      json_member(json_attribute(parsed, "neg_inf").unwrap(), "doubleValue"),
    ),
    "-Infinity",
  )
}

///|
test "json_encoder_groups_by_resource_and_scope" {
  let second_resource : Map[String, @sdk.AttributeValue] = Map([])
  second_resource.set(@sdk.SERVICE_NAME, @sdk.StringValue("other-service"))
  let first : @sdk.SpanData = { ..json_test_span(), name: "one" }
  let second : @sdk.SpanData = {
    ..json_test_span(),
    name: "two",
    scope_name: "other-scope",
  }
  let third : @sdk.SpanData = {
    ..json_test_span(),
    name: "three",
    resource: second_resource,
  }
  let root = encode_json([first, second, third])
  let resource_spans = json_array_value(json_member(root, "resourceSpans"))
  assert_eq(resource_spans.length(), 2)
  let scopes = json_array_value(json_member(resource_spans[0], "scopeSpans"))
  assert_eq(scopes.length(), 2)
  let first_spans = json_array_value(json_member(scopes[0], "spans"))
  let second_spans = json_array_value(json_member(scopes[1], "spans"))
  assert_eq(first_spans.length(), 1)
  assert_eq(second_spans.length(), 1)
  assert_eq(json_string_value(json_member(first_spans[0], "name")), "one")
  assert_eq(json_string_value(json_member(second_spans[0], "name")), "two")
}
