///|
fn scan_unicode_span() -> @sdk.SpanData {
  let attributes : Map[String, @sdk.AttributeValue] = Map::new()
  attributes.set("unicode", @sdk.StringValue("héllo·世界😀"))
  attributes.set("empty", @sdk.StringValue(""))
  attributes.set("neg", @sdk.IntValue(-5L))
  attributes.set("big", @sdk.IntValue(9223372036854775807L))
  attributes.set("dbl", @sdk.DoubleValue(3.14159))
  attributes.set("yes", @sdk.BoolValue(true))
  attributes.set("no", @sdk.BoolValue(false))
  attributes.set("strs", @sdk.StringArrayValue(["a", "β", ""]))
  attributes.set("bools", @sdk.BoolArrayValue([true, false]))
  attributes.set("ints", @sdk.IntArrayValue([-1L, 2L]))
  attributes.set("dbls", @sdk.DoubleArrayValue([1.5, -2.5]))
  let event_attributes : Map[String, @sdk.AttributeValue] = Map::new()
  event_attributes.set("ek", @sdk.StringValue("év😀"))
  let link_attributes : Map[String, @sdk.AttributeValue] = Map::new()
  link_attributes.set("lk", @sdk.IntValue(9L))
  let resource : Map[String, @sdk.AttributeValue] = Map::new()
  resource.set(@sdk.SERVICE_NAME, @sdk.StringValue("scan·资源"))
  resource.set("b", @sdk.BoolValue(false))
  {
    name: "scan·span",
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      3,
      tracestate="a=b,c=d",
    ),
    parent_span_id: @api.bytes_from_hex("1122334455667788").unwrap(),
    kind: @api.SpanKind::Consumer,
    start_time_unix_nano: 42L,
    end_time_unix_nano: 1600000000500000000L,
    attributes,
    events: [
      {
        name: "ev·😀",
        time_unix_nano: 7L,
        attributes: event_attributes,
        dropped_attributes_count: 2,
      },
    ],
    links: [
      {
        span_context: @api.span_context(
          @api.bytes_from_hex("0102030405060708090a0b0c0d0e0f10").unwrap(),
          @api.bytes_from_hex("1112131415161718").unwrap(),
          1,
          tracestate="x=y",
        ),
        attributes: link_attributes,
        dropped_attributes_count: 1,
      },
    ],
    dropped_attributes_count: 3,
    dropped_events_count: 4,
    dropped_links_count: 5,
    status: @api.StatusCode::Error,
    status_description: "oops·😀",
    resource,
    scope_name: "scan-scope",
    scope_version: "1.0",
  }
}

///|
fn scan_any_value(span_fields : Array[Field], key : String) -> Array[Field] {
  for attribute in fields_of(span_fields, 9) {
    let kv = parse_fields(attribute.payload)
    match first_of(kv, 1) {
      Some(key_field) =>
        if (key_field.payload |> @utf8.decode_lossy) == key {
          match first_of(kv, 2) {
            Some(any) => return parse_fields(any.payload)
            None => ()
          }
        }
      None => ()
    }
  }
  []
}

///|
test "scan_complex_span_wire_shape" {
  let span_fields = link_test_span_fields(scan_unicode_span())
  assert_eq(
    field_hex(first_of(span_fields, 1).unwrap()),
    "4bf92f359d1e75b7618a2d1f3c4e5a6b",
  )
  assert_eq(field_hex(first_of(span_fields, 2).unwrap()), "00f067aa0ba902b7")
  assert_eq(
    first_of(span_fields, 3).unwrap().payload |> @utf8.decode_lossy,
    "a=b,c=d",
  )
  assert_eq(field_hex(first_of(span_fields, 4).unwrap()), "1122334455667788")
  assert_eq(
    first_of(span_fields, 5).unwrap().payload |> @utf8.decode_lossy,
    "scan·span",
  )
  assert_eq(first_of(span_fields, 6).unwrap().varint, 5)
  assert_eq(
    fixed64_value(first_of(span_fields, 7).unwrap().payload).reinterpret_as_int64(),
    42L,
  )
  assert_eq(
    fixed64_value(first_of(span_fields, 8).unwrap().payload).reinterpret_as_int64(),
    1600000000500000000L,
  )
  assert_eq(first_of(span_fields, 10).unwrap().varint, 3)
  assert_eq(first_of(span_fields, 12).unwrap().varint, 4)
  assert_eq(first_of(span_fields, 14).unwrap().varint, 5)
  let span_flags = first_of(span_fields, 16).unwrap()
  assert_eq(span_flags.wire, 5)
  assert_eq(span_flags.payload.at(0).to_int() & 0xFF, 3)
  let status = parse_fields(first_of(span_fields, 15).unwrap().payload)
  assert_eq(
    first_of(status, 2).unwrap().payload |> @utf8.decode_lossy,
    "oops·😀",
  )
  assert_eq(first_of(status, 3).unwrap().varint, 2)
  assert_eq(
    first_of(scan_any_value(span_fields, "unicode"), 1).unwrap().payload
    |> @utf8.decode_lossy,
    "héllo·世界😀",
  )
  assert_eq(
    first_of(scan_any_value(span_fields, "empty"), 1).unwrap().payload.length(),
    0,
  )
  assert_eq(first_of(scan_any_value(span_fields, "yes"), 2).unwrap().varint, 1)
  assert_eq(first_of(scan_any_value(span_fields, "no"), 2).unwrap().varint, 0)
  assert_eq(
    first_of(scan_any_value(span_fields, "neg"), 3).unwrap().varint.reinterpret_as_int64(),
    -5L,
  )
  assert_eq(
    first_of(scan_any_value(span_fields, "big"), 3).unwrap().varint.reinterpret_as_int64(),
    9223372036854775807L,
  )
  let strs = fields_of(
    parse_fields(first_of(scan_any_value(span_fields, "strs"), 5).unwrap().payload),
    1,
  )
  assert_eq(strs.length(), 3)
  assert_eq(
    first_of(parse_fields(strs[0].payload), 1).unwrap().payload
    |> @utf8.decode_lossy,
    "a",
  )
  assert_eq(
    first_of(parse_fields(strs[1].payload), 1).unwrap().payload
    |> @utf8.decode_lossy,
    "β",
  )
  assert_eq(first_of(parse_fields(strs[2].payload), 1).unwrap().payload.length(), 0)
  let bools = fields_of(
    parse_fields(first_of(scan_any_value(span_fields, "bools"), 5).unwrap().payload),
    1,
  )
  assert_eq(bools.length(), 2)
  assert_eq(first_of(parse_fields(bools[0].payload), 2).unwrap().varint, 1)
  assert_eq(first_of(parse_fields(bools[1].payload), 2).unwrap().varint, 0)
  let ints = fields_of(
    parse_fields(first_of(scan_any_value(span_fields, "ints"), 5).unwrap().payload),
    1,
  )
  assert_eq(ints.length(), 2)
  assert_eq(
    first_of(parse_fields(ints[0].payload), 3).unwrap().varint.reinterpret_as_int64(),
    -1L,
  )
  assert_eq(
    first_of(parse_fields(ints[1].payload), 3).unwrap().varint.reinterpret_as_int64(),
    2L,
  )
  let dbls = fields_of(
    parse_fields(first_of(scan_any_value(span_fields, "dbls"), 5).unwrap().payload),
    1,
  )
  assert_eq(dbls.length(), 2)
  let event = parse_fields(fields_of(span_fields, 11)[0].payload)
  assert_eq(
    fixed64_value(first_of(event, 1).unwrap().payload).reinterpret_as_int64(),
    7L,
  )
  assert_eq(
    first_of(event, 2).unwrap().payload |> @utf8.decode_lossy,
    "ev·😀",
  )
  assert_eq(first_of(event, 4).unwrap().varint, 2)
  let link = parse_fields(fields_of(span_fields, 13)[0].payload)
  assert_eq(
    field_hex(first_of(link, 1).unwrap()),
    "0102030405060708090a0b0c0d0e0f10",
  )
  assert_eq(field_hex(first_of(link, 2).unwrap()), "1112131415161718")
  assert_eq(first_of(link, 3).unwrap().payload |> @utf8.decode_lossy, "x=y")
  let link_any = parse_fields(
    first_of(parse_fields(fields_of(link, 4)[0].payload), 2).unwrap().payload,
  )
  assert_eq(first_of(link_any, 3).unwrap().varint, 9)
  assert_eq(first_of(link, 5).unwrap().varint, 1)
  let link_flags = first_of(link, 6).unwrap()
  assert_eq(link_flags.wire, 5)
  assert_eq(link_flags.payload.at(0).to_int() & 0xFF, 1)
}
