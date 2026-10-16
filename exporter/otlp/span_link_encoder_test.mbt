// Wire-format tests for OTLP span links (Span.links, field 13).

///|
fn link_test_span_fields(span : @sdk.SpanData) -> Array[Field] {
  let encoded = @otlp.encode_trace_request([span])
  let request = parse_fields(encoded.exact_view())
  let resource_spans = parse_fields(fields_of(request, 1)[0].payload)
  let scope_spans = parse_fields(first_of(resource_spans, 2).unwrap().payload)
  parse_fields(first_of(scope_spans, 2).unwrap().payload)
}

///|
fn field_hex(field : Field) -> String {
  @api.bytes_to_hex(field.payload.to_array().map(byte_to_int))
}

///|
test "encode_span_writes_links_with_attributes_and_tracestate" {
  let span = sample_span()
  let link_context = @api.span_context(
    @api.bytes_from_hex("0af7651916cd43dd8448eb211c80319c").unwrap(),
    @api.bytes_from_hex("b7ad6b7169203331").unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
  ).with_tracestate("vendor=1")
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("link.reason", @sdk.StringValue("retry"))
  let second_context = @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("1122334455667788").unwrap(),
    0,
  )
  let with_links : @sdk.SpanData = {
    ..span,
    links: [
      @sdk.SpanLink::new(link_context, attributes~),
      @sdk.SpanLink::new(second_context),
    ],
  }
  let span_fields = link_test_span_fields(with_links)
  let links = fields_of(span_fields, 13)
  assert_eq(links.length(), 2)
  let first = parse_fields(links[0].payload)
  assert_eq(
    field_hex(first_of(first, 1).unwrap()),
    "0af7651916cd43dd8448eb211c80319c",
  )
  assert_eq(field_hex(first_of(first, 2).unwrap()), "b7ad6b7169203331")
  assert_eq(
    first_of(first, 3).unwrap().payload |> @utf8.decode_lossy,
    "vendor=1",
  )
  let link_attributes = fields_of(first, 4)
  assert_eq(link_attributes.length(), 1)
  let kv = parse_fields(link_attributes[0].payload)
  assert_eq(
    first_of(kv, 1).unwrap().payload |> @utf8.decode_lossy,
    "link.reason",
  )
  let link_any = parse_fields(first_of(kv, 2).unwrap().payload)
  assert_eq(
    first_of(link_any, 1).unwrap().payload |> @utf8.decode_lossy,
    "retry",
  )
  let flags = first_of(first, 6).unwrap()
  assert_eq(flags.wire, 5)
  assert_eq(flags.payload.at(0).to_int() & 0xFF, 1)
  let second = parse_fields(links[1].payload)
  assert_eq(
    field_hex(first_of(second, 1).unwrap()),
    "4bf92f359d1e75b7618a2d1f3c4e5a6b",
  )
  assert_true(first_of(second, 3) is None)
  assert_eq(fields_of(second, 4).length(), 0)
}

///|
test "encode_span_without_links_omits_the_link_field" {
  let span_fields = link_test_span_fields(sample_span())
  assert_true(first_of(span_fields, 13) is None)
}
