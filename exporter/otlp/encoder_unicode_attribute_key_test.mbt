// Non-ASCII attribute keys and values take the generic UTF-8 encoding path
// after the ASCII fast path rolls back.

test "encode_attributes_falls_back_for_non_ascii_keys" {
  let template = sample_span()
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("clé", @sdk.StringValue("vàlue"))
  attributes.set("中", @sdk.BoolValue(true))
  attributes.set("🤣", @sdk.IntValue(1234L))
  attributes.set("émoji", @sdk.DoubleValue(2.5))
  let span : @sdk.SpanData = { ..template, attributes, links: [], }
  let span_fields = link_test_span_fields(span)
  let text = scalar_attribute_fields(span_fields, "clé")
  assert_eq(first_of(text, 1).unwrap().payload |> @utf8.decode_lossy, "vàlue")
  assert_eq(
    first_of(scalar_attribute_fields(span_fields, "中"), 2).unwrap().varint,
    1,
  )
  assert_eq(
    first_of(scalar_attribute_fields(span_fields, "🤣"), 3).unwrap().varint.reinterpret_as_int64(),
    1234L,
  )
  assert_eq(
    fixed64_value(
      first_of(scalar_attribute_fields(span_fields, "émoji"), 4).unwrap().payload,
    ),
    0x4004000000000000UL,
  )
}
