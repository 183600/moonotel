test "scratch_span_context_from_hex_roundtrip" {
  let sc = @api.span_context_from_hex(
    "4bf92f359d1e75b7618a2d1f3c4e5a6b",
    "00f067aa0ba902b7",
    1,
  )
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
  assert_eq(sc.span_id_hex(), "00f067aa0ba902b7")
  assert_eq(sc.trace_flags(), 1)
}

test "scratch_span_context_from_hex_uppercase" {
  let sc = @api.span_context_from_hex(
    "4BF92F359D1E75B7618A2D1F3C4E5A6B",
    "00F067AA0BA902B7",
    0,
  )
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
}

test "scratch_span_context_from_hex_rejects" {
  assert_false(@api.span_context_from_hex("", "", 1).is_valid())
  assert_false(
    @api.span_context_from_hex("zz", "00f067aa0ba902b7", 1).is_valid(),
  )
  assert_false(
    @api.span_context_from_hex(
      "4bf92f359d1e75b7618a2d1f3c4e5a6g",
      "00f067aa0ba902b7",
      1,
    ).is_valid(),
  )
  assert_false(
    @api.span_context_from_hex(
      "00000000000000000000000000000000",
      "00f067aa0ba902b7",
      1,
    ).is_valid(),
  )
  assert_false(
    @api.span_context_from_hex(
      "4bf92f359d1e75b7618a2d1f3c4e5a6b",
      "0000000000000000",
      1,
    ).is_valid(),
  )
}

test "scratch_bytes_from_hex_odd_and_invalid" {
  assert_eq(@api.bytes_from_hex("abc"), None)
  assert_eq(@api.bytes_from_hex("zz"), None)
  let empty : Array[Int] = []
  assert_eq(@api.bytes_from_hex(""), Some(empty))
  assert_eq(@api.bytes_from_hex("0a"), Some([10]))
  assert_eq(@api.bytes_from_hex("0A"), Some([10]))
  assert_eq(@api.bytes_from_hex("ffFF"), Some([255, 255]))
}

test "scratch_span_kind_and_status_code_mappings" {
  assert_eq(@api.SpanKind::Internal.to_string(), "internal")
  assert_eq(@api.SpanKind::Server.to_string(), "server")
  assert_eq(@api.SpanKind::Client.to_string(), "client")
  assert_eq(@api.SpanKind::Producer.to_string(), "producer")
  assert_eq(@api.SpanKind::Consumer.to_string(), "consumer")
  assert_eq(@api.SpanKind::Client.otlp_value(), 3)
  assert_eq(@api.SpanKind::Consumer.otlp_value(), 5)
  assert_eq(@api.StatusCode::Unset.to_string(), "unset")
  assert_eq(@api.StatusCode::Ok.to_string(), "ok")
  assert_eq(@api.StatusCode::Error.to_string(), "error")
  assert_eq(@api.StatusCode::Unset.otlp_value(), 0)
  assert_eq(@api.StatusCode::Error.otlp_value(), 2)
}

test "scratch_trace_id_copy_isolation" {
  let id : Array[Int] = [1, 2, 3]
  let sc = @api.span_context(id, [4, 5, 6], 1)
  let copy = sc.trace_id()
  copy[0] = 99
  assert_eq(sc.trace_id_view()[0], 1)
  assert_eq(id[0], 1)
}
