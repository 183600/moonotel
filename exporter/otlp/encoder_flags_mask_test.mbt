// OTLP `flags` is a 32-bit bit field whose bits 0-7 hold the W3C trace flags.
// When a span/link message is created from a runtime SpanContext, the high
// bits must be zero rather than a copy of an oversized trace-flags value.

///|
fn flags_mask_span(trace_flags : Int32) -> @sdk.SpanData {
  let link_context = @api.span_context(
    @api.bytes_from_hex("0af7651916cd43dd8448eb211c80319c").unwrap(),
    @api.bytes_from_hex("b7ad6b7169203331").unwrap(),
    trace_flags,
  )
  {
    ..sample_span(),
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      trace_flags,
    ),
    links: [@sdk.SpanLink::new(link_context)],
  }
}

///|
test "protobuf_flags_drop_reserved_high_bits" {
  let span_fields = link_test_span_fields(flags_mask_span(0x1FF))
  let span_flags = first_of(span_fields, 16).unwrap()
  assert_eq(span_flags.wire, 5)
  assert_eq(span_flags.payload.at(0).to_int() & 0xFF, 0xFF)
  assert_eq(span_flags.payload.at(1).to_int(), 0)
  assert_eq(span_flags.payload.at(2).to_int(), 0)
  assert_eq(span_flags.payload.at(3).to_int(), 0)
  let link = parse_fields(fields_of(span_fields, 13)[0].payload)
  let link_flags = first_of(link, 6).unwrap()
  assert_eq(link_flags.wire, 5)
  assert_eq(link_flags.payload.at(0).to_int() & 0xFF, 0xFF)
  assert_eq(link_flags.payload.at(1).to_int(), 0)
  assert_eq(link_flags.payload.at(2).to_int(), 0)
  assert_eq(link_flags.payload.at(3).to_int(), 0)
}

///|
test "json_flags_drop_reserved_high_bits" {
  let root = encode_json([flags_mask_span(0x1FF)])
  let span = json_span_of(
    json_array_value(json_member(root, "resourceSpans"))[0],
    0,
  )
  assert_eq(json_number_value(json_member(span, "flags")), 255.0)
  let links = json_array_value(json_member(span, "links"))
  assert_eq(json_number_value(json_member(links[0], "flags")), 255.0)
}
