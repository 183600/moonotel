// Malformed OTLP response bodies must be reported as failures while unknown
// but well-formed fields are skipped.

test "decode_export_response_rejects_overlong_varint" {
  let result = @otlp.decode_export_response(
    b"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
  )
  assert_false(result.is_success())
}

test "decode_export_response_rejects_truncated_varint_field_value" {
  let result = @otlp.decode_export_response(b"\x08\xFF")
  assert_false(result.is_success())
}

test "decode_export_response_rejects_truncated_partial_success" {
  let result = @otlp.decode_export_response(b"\x0A\x01\xFF")
  assert_false(result.is_success())
}

test "decode_export_response_rejects_partial_success_with_truncated_value" {
  // partial_success { rejected_spans = <truncated> }
  let result = @otlp.decode_export_response(b"\x0A\x02\x08")
  assert_false(result.is_success())
}

test "decode_export_response_rejects_group_wire_types" {
  assert_false(@otlp.decode_export_response(b"\x0F").is_success())
}

test "decode_export_response_skips_unknown_fixed64_fields" {
  let result = @otlp.decode_export_response(
    b"\x09\x01\x02\x03\x04\x05\x06\x07\x08",
  )
  assert_true(result.is_success())
}

test "decode_export_response_skips_unknown_fixed32_fields" {
  let result = @otlp.decode_export_response(b"\x0D\x01\x02\x03\x04")
  assert_true(result.is_success())
}

test "decode_export_response_rejects_truncated_fixed32_fields" {
  assert_false(@otlp.decode_export_response(b"\x0D\x01\x02").is_success())
}
