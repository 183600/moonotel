// OTLP link flags bits 8-9 describe whether the linked SpanContext came from a
// remote peer. The encoders must keep the W3C trace-flag byte and add the
// remote state only for remote links.

///|
fn remote_link_test_span(trace_flags : Int32, is_remote : Bool) -> @sdk.SpanData {
  let link_context = @api.span_context(
    @api.bytes_from_hex("0af7651916cd43dd8448eb211c80319c").unwrap(),
    @api.bytes_from_hex("b7ad6b7169203331").unwrap(),
    trace_flags,
    is_remote~,
  )
  { ..sample_span(), links: [@sdk.SpanLink::new(link_context)] }
}

///|
fn fixed32_value(field : Field) -> Int {
  field.payload.at(0).to_int() |
  (field.payload.at(1).to_int() << 8) |
  (field.payload.at(2).to_int() << 16) |
  (field.payload.at(3).to_int() << 24)
}

///|
test "protobuf_flags_encode_remote_link_state" {
  let span_fields = link_test_span_fields(remote_link_test_span(0x1FF, true))
  let link = parse_fields(fields_of(span_fields, 13)[0].payload)
  let flags = first_of(link, 6).unwrap()
  assert_eq(flags.wire, 5)
  assert_eq(fixed32_value(flags), 0x3FF)
}

///|
test "protobuf_flags_leave_local_link_state_unknown" {
  let span_fields = link_test_span_fields(remote_link_test_span(0x1FF, false))
  let link = parse_fields(fields_of(span_fields, 13)[0].payload)
  let flags = first_of(link, 6).unwrap()
  assert_eq(flags.wire, 5)
  assert_eq(fixed32_value(flags), 0xFF)
}

///|
test "json_flags_encode_remote_link_state" {
  let root = encode_json([remote_link_test_span(0x1FF, true)])
  let span = json_span_of(
    json_array_value(json_member(root, "resourceSpans"))[0],
    0,
  )
  let link = json_array_value(json_member(span, "links"))[0]
  assert_eq(json_number_value(json_member(link, "flags")), 1023.0)
}

///|
test "json_flags_leave_local_link_state_unknown" {
  let root = encode_json([remote_link_test_span(0x1FF, false)])
  let span = json_span_of(
    json_array_value(json_member(root, "resourceSpans"))[0],
    0,
  )
  let link = json_array_value(json_member(span, "links"))[0]
  assert_eq(json_number_value(json_member(link, "flags")), 255.0)
}
