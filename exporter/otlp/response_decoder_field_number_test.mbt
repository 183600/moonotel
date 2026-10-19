// Protobuf field numbers are 1-based and limited to 29 bits. A body that
// uses field number 0 (or an out-of-range field number) is malformed even
// when its wire type is otherwise valid.

///|
test "decode_export_response_rejects_field_number_zero" {
  // tag = field 0, wire type 0; value = 0
  assert_false(@otlp.decode_export_response(b"\x00\x00").is_success())
  // tag = field 0, wire type 2; length = 0
  assert_false(@otlp.decode_export_response(b"\x02\x00").is_success())
  // tag = field 0, wire type 5; four payload bytes
  assert_false(@otlp.decode_export_response(b"\x05\x01\x02\x03\x04").is_success())
}

///|
test "decode_export_response_rejects_out_of_range_field_number" {
  // field number 2^29, wire type 0; value = 0
  assert_false(
    @otlp.decode_export_response(b"\x80\x80\x80\x80\x10\x00").is_success(),
  )
}

///|
test "decode_export_response_accepts_largest_field_number" {
  // field number 2^29 - 1, wire type 0; value = 0 (unknown field is skipped)
  assert_true(
    @otlp.decode_export_response(b"\xF8\xFF\xFF\xFF\x0F\x00").is_success(),
  )
}

///|
test "decode_export_response_rejects_field_number_zero_inside_partial_success" {
  // partial_success { field 0, wire type 0 = 0 }
  assert_false(@otlp.decode_export_response(b"\x0A\x02\x00\x00").is_success())
}
