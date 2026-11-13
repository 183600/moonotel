// Wire-format tests for the scalar attribute value types and for buffer
// growth on large string values.

///|
fn scalar_attribute_fields(
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
      return parse_fields(first_of(kv, 2).unwrap().payload)
    }
  }
  []
}

///|
test "encode_scalar_attribute_values" {
  let template = sample_span()
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("text", @sdk.StringValue("héllo"))
  attributes.set("flag", @sdk.BoolValue(true))
  attributes.set("count", @sdk.IntValue(-2L))
  attributes.set("ratio", @sdk.DoubleValue(1.5))
  let span : @sdk.SpanData = { ..template, attributes, links: [], }
  let span_fields = link_test_span_fields(span)
  let text = scalar_attribute_fields(span_fields, "text")
  assert_eq(first_of(text, 1).unwrap().payload |> @utf8.decode_lossy, "héllo")
  assert_eq(
    first_of(scalar_attribute_fields(span_fields, "flag"), 2).unwrap().varint,
    1,
  )
  assert_eq(
    first_of(scalar_attribute_fields(span_fields, "count"), 3).unwrap().varint.reinterpret_as_int64(),
    -2L,
  )
  assert_eq(
    fixed64_value(
      first_of(scalar_attribute_fields(span_fields, "ratio"), 4).unwrap().payload,
    ),
    0x3FF8000000000000UL,
  )
}

///|
test "encode_int_attributes_across_varint_sizes" {
  // Boundaries for the 1- through 9-byte unsigned varint encodings, plus
  // negative values which always use the full 10-byte two's-complement form.
  let values : Array[Int64] = [
    0L,
    127L,
    128L,
    16383L,
    16384L,
    2097151L,
    2097152L,
    268435455L,
    268435456L,
    34359738367L,
    34359738368L,
    4398046511103L,
    4398046511104L,
    562949953421311L,
    562949953421312L,
    72057594037927935L,
    72057594037927936L,
    9223372036854775807L,
    -1L,
    -2L,
  ]
  for value in values {
    let attributes : Map[String, @sdk.AttributeValue] = Map([])
    attributes.set("count", @sdk.IntValue(value))
    let span : @sdk.SpanData = { ..sample_span(), attributes, links: [], }
    let span_fields = link_test_span_fields(span)
    let any = scalar_attribute_fields(span_fields, "count")
    assert_eq(
      first_of(any, 3).unwrap().varint.reinterpret_as_int64(),
      value,
    )
  }
}

///|
test "encode_large_string_attribute_grows_the_buffer" {
  let template = sample_span()
  let big = StringBuilder()
  for i = 0; i < 20000; i = i + 1 {
    big.write_char('x')
  }
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("big", @sdk.StringValue(big.to_string()))
  let span : @sdk.SpanData = { ..template, attributes, links: [], }
  let span_fields = link_test_span_fields(span)
  let encoded = scalar_attribute_fields(span_fields, "big")
  assert_eq(first_of(encoded, 1).unwrap().payload.length(), 20000)
}
