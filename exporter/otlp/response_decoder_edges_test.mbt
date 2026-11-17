// Malformed OTLP response bodies must be reported as failures while unknown
// but well-formed fields are skipped.

///|
test "decode_export_response_rejects_overlong_varint" {
  let result = @otlp.decode_export_response(
    b"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
  )
  assert_false(result.is_success())
}

///|
test "decode_export_response_rejects_truncated_varint_field_value" {
  let result = @otlp.decode_export_response(b"\x08\xFF")
  assert_false(result.is_success())
}

///|
test "decode_export_response_rejects_truncated_partial_success" {
  let result = @otlp.decode_export_response(b"\x0A\x01\xFF")
  assert_false(result.is_success())
}

///|
test "decode_export_response_rejects_partial_success_with_truncated_value" {
  // partial_success { rejected_spans = <truncated> }
  let result = @otlp.decode_export_response(b"\x0A\x02\x08")
  assert_false(result.is_success())
}

///|
test "decode_export_response_rejects_truncated_partial_success_varint" {
  // partial_success { rejected_spans = <varint continues past the end> }
  let result = @otlp.decode_export_response(b"\x0A\x02\x08\x80")
  assert_false(result.is_success())
}

///|
test "decode_export_response_rejects_truncated_partial_success_length" {
  // partial_success { error_message = <length continues past the end> }
  let result = @otlp.decode_export_response(b"\x0A\x02\x12\x80")
  assert_false(result.is_success())
}

///|
test "decode_export_response_rejects_partial_success_length_past_end" {
  // partial_success { error_message = <5 bytes> } but the partial message is empty
  let result = @otlp.decode_export_response(b"\x0A\x02\x12\x05")
  assert_false(result.is_success())
}

///|
test "decode_export_response_rejects_truncated_inner_fixed64" {
  // partial_success { rejected_spans = <fixed64 wire type, no payload> }
  let result = @otlp.decode_export_response(b"\x0A\x01\x09")
  assert_false(result.is_success())
}

///|
test "decode_export_response_rejects_truncated_inner_fixed32" {
  // partial_success { rejected_spans = <fixed32 wire type, no payload> }
  let result = @otlp.decode_export_response(b"\x0A\x01\x0D")
  assert_false(result.is_success())
}

///|
test "decode_export_response_rejects_inner_group_wire_types" {
  // partial_success { rejected_spans = <start-group wire type> }
  let result = @otlp.decode_export_response(b"\x0A\x01\x0B")
  assert_false(result.is_success())
}

///|
test "decode_export_response_rejects_zero_inner_field_number" {
  // partial_success { rejected_spans = <tag with field number 0> }
  let result = @otlp.decode_export_response(b"\x0A\x01\x00")
  assert_false(result.is_success())
}

///|
test "decode_export_response_rejects_group_wire_types" {
  assert_false(@otlp.decode_export_response(b"\x0F").is_success())
}

///|
test "decode_export_response_skips_unknown_fixed64_fields" {
  let result = @otlp.decode_export_response(
    b"\x09\x01\x02\x03\x04\x05\x06\x07\x08",
  )
  assert_true(result.is_success())
}

///|
test "decode_export_response_skips_unknown_fixed32_fields" {
  let result = @otlp.decode_export_response(b"\x0D\x01\x02\x03\x04")
  assert_true(result.is_success())
}

///|
test "decode_export_response_rejects_truncated_fixed32_fields" {
  assert_false(@otlp.decode_export_response(b"\x0D\x01\x02").is_success())
}
