// Wire-format tests for the non-string array attribute types.

///|
fn probe_span_with(
  resource : Map[String, @sdk.AttributeValue],
) -> @sdk.SpanData {
  {
    name: "probe",
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map::new(),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource,
    scope_name: "scope",
    scope_version: "",
  }
}

///|
fn probe_resource_group_count(
  r1 : Map[String, @sdk.AttributeValue],
  r2 : Map[String, @sdk.AttributeValue],
) -> Int32 {
  let encoded = @otlp.encode_trace_request([
    probe_span_with(r1),
    probe_span_with(r2),
  ])
  let request = parse_fields(encoded.exact_view())
  fields_of(request, 1).length()
}

///|
fn array_value_elements(
  span_fields : Array[Field],
  key : String,
) -> Array[Field] {
  for attribute in fields_of(span_fields, 9) {
    let kv = parse_fields(attribute.payload)
    let kv_key = match first_of(kv, 1) {
      Some(field) => field.payload |> @utf8.decode_lossy
      None => ""
    }
    if kv_key == key {
      let any = parse_fields(first_of(kv, 2).unwrap().payload)
      return fields_of(parse_fields(first_of(any, 5).unwrap().payload), 1)
    }
  }
  []
}

///|
test "encode_attribute_arrays" {
  let template = sample_span()
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("bools", @sdk.BoolArrayValue([true, false]))
  attributes.set("ints", @sdk.IntArrayValue([1L, -2L]))
  attributes.set("doubles", @sdk.DoubleArrayValue([1.5]))
  attributes.set("strings", @sdk.StringArrayValue(["a", "b"]))
  let span : @sdk.SpanData = { ..template, attributes, links: [], }
  let span_fields = link_test_span_fields(span)
  let bools = array_value_elements(span_fields, "bools")
  assert_eq(bools.length(), 2)
  assert_eq(first_of(parse_fields(bools[0].payload), 2).unwrap().varint, 1)
  assert_eq(first_of(parse_fields(bools[1].payload), 2).unwrap().varint, 0)
  let ints = array_value_elements(span_fields, "ints")
  assert_eq(ints.length(), 2)
  assert_eq(
    first_of(parse_fields(ints[0].payload), 3).unwrap().varint.reinterpret_as_int64(),
    1L,
  )
  assert_eq(
    first_of(parse_fields(ints[1].payload), 3).unwrap().varint.reinterpret_as_int64(),
    -2L,
  )
  let doubles = array_value_elements(span_fields, "doubles")
  assert_eq(doubles.length(), 1)
  let double_bits = first_of(parse_fields(doubles[0].payload), 4).unwrap()
  assert_eq(fixed64_value(double_bits.payload), 0x3FF8000000000000UL)
  let strings = array_value_elements(span_fields, "strings")
  assert_eq(strings.length(), 2)
  assert_eq(
    first_of(parse_fields(strings[1].payload), 1).unwrap().payload
    |> @utf8.decode_lossy,
    "b",
  )
}

///|
test "attribute_arrays_of_different_types_are_distinct_resource_keys" {
  let r1 : Map[String, @sdk.AttributeValue] = Map([])
  r1.set("a", @sdk.BoolArrayValue([true]))
  let r2 : Map[String, @sdk.AttributeValue] = Map([])
  r2.set("a", @sdk.IntArrayValue([1L]))
  assert_eq(probe_resource_group_count(r1, r2), 2)
}

///|
test "attribute_arrays_with_equal_contents_share_resource_keys" {
  let r1 : Map[String, @sdk.AttributeValue] = Map([])
  r1.set("a", @sdk.IntArrayValue([1L, 2L]))
  let r2 : Map[String, @sdk.AttributeValue] = Map([])
  r2.set("a", @sdk.IntArrayValue([1L, 2L]))
  assert_eq(probe_resource_group_count(r1, r2), 1)
}
