///|
test "encode_all_attribute_types_and_unicode" {
  let long_resource = "r" + "x".repeat(2000)
  let attributes : Map[String, @sdk.AttributeValue] = Map::new()
  attributes.set("s", @sdk.StringValue("héllo😀"))
  attributes.set("b", @sdk.BoolValue(true))
  attributes.set("i", @sdk.IntValue(-5L))
  attributes.set("d", @sdk.DoubleValue(3.25))
  attributes.set("arr", @sdk.StringArrayValue(["x", "y😀", ""]))
  let event_attributes : Map[String, @sdk.AttributeValue] = Map::new()
  event_attributes.set("ek", @sdk.StringValue("év"))
  let resource : Map[String, @sdk.AttributeValue] = Map::new()
  resource.set(@sdk.SERVICE_NAME, @sdk.StringValue(long_resource))
  let span : @sdk.SpanData = {
    name: "名😀name",
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: @api.bytes_from_hex("1122334455667788").unwrap(),
    kind: @api.SpanKind::Producer,
    start_time_unix_nano: -1L,
    end_time_unix_nano: 1600000000500000000L,
    attributes,
    events: [
      { name: "ev😀", time_unix_nano: 42L, attributes: event_attributes, },
    ],
    links: [],
    status: @api.StatusCode::Error,
    status_description: "oops😀",
    resource,
    scope_name: "scope-unicode-😀",
    scope_version: "9.9",
  }
  let encoded = @otlp.encode_trace_request([span])
  let request = parse_fields(encoded.exact_view())
  let resource_spans = fields_of(request, 1)
  assert_eq(resource_spans.length(), 1)
  let rs_fields = parse_fields(resource_spans[0].payload)
  let resource_field = first_of(rs_fields, 1).unwrap()
  let resource_fields = parse_fields(resource_field.payload)
  let resource_attr = fields_of(resource_fields, 1)[0]
  let resource_kv = parse_fields(resource_attr.payload)
  assert_eq(
    first_of(resource_kv, 1).unwrap().payload |> @utf8.decode_lossy,
    @sdk.SERVICE_NAME,
  )
  let resource_any = parse_fields(first_of(resource_kv, 2).unwrap().payload)
  assert_eq(
    first_of(resource_any, 1).unwrap().payload |> @utf8.decode_lossy,
    long_resource,
  )
  let scope_spans = first_of(rs_fields, 2).unwrap()
  let ss_fields = parse_fields(scope_spans.payload)
  assert_eq(
    first_of(parse_fields(first_of(ss_fields, 1).unwrap().payload), 1).unwrap().payload
    |> @utf8.decode_lossy,
    "scope-unicode-😀",
  )
  let span_fields = parse_fields(first_of(ss_fields, 2).unwrap().payload)
  assert_eq(
    first_of(span_fields, 5).unwrap().payload |> @utf8.decode_lossy,
    "名😀name",
  )
  assert_eq(first_of(span_fields, 6).unwrap().varint, 4)
  assert_eq(
    fixed64_value(first_of(span_fields, 7).unwrap().payload).reinterpret_as_int64(),
    -1L,
  )
  assert_eq(attribute_value(span_fields, "s"), Some("héllo😀"))
  // bool
  let bool_any = parse_fields(
    first_of(parse_fields(fields_of(span_fields, 9)[1].payload), 2).unwrap().payload,
  )
  assert_eq(first_of(bool_any, 2).unwrap().varint, 1)
  // string array
  for attribute in fields_of(span_fields, 9) {
    let kv = parse_fields(attribute.payload)
    let key = match first_of(kv, 1) {
      Some(field) => field.payload |> @utf8.decode_lossy
      None => ""
    }
    if key == "arr" {
      let any = parse_fields(first_of(kv, 2).unwrap().payload)
      let array = parse_fields(first_of(any, 5).unwrap().payload)
      let elements = fields_of(array, 1)
      assert_eq(elements.length(), 3)
      assert_eq(
        first_of(parse_fields(elements[1].payload), 1).unwrap().payload
        |> @utf8.decode_lossy,
        "y😀",
      )
    }
  }
  let status = parse_fields(first_of(span_fields, 15).unwrap().payload)
  assert_eq(
    first_of(status, 2).unwrap().payload |> @utf8.decode_lossy,
    "oops😀",
  )
  let event = parse_fields(fields_of(span_fields, 11)[0].payload)
  assert_eq(first_of(event, 2).unwrap().payload |> @utf8.decode_lossy, "ev😀")
  assert_eq(fixed64_value(first_of(event, 1).unwrap().payload), 42)
}
