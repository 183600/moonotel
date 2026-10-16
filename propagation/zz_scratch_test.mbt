test "scratch_parse_traceparent_uppercase_hex" {
  let value = "00-4BF92F359D1E75B7618A2D1F3C4E5A6B-00F067AA0BA902B7-01"
  match @propagation.parse_traceparent(value) {
    Some(sc) => {
      assert_true(sc.is_valid())
      assert_true(sc.is_sampled())
      assert_eq(sc.trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
    }
    None => fail("uppercase hex should parse")
  }
}

test "scratch_parse_traceparent_rejects_bad_inputs" {
  assert_true(@propagation.parse_traceparent("") is None)
  assert_true(@propagation.parse_traceparent("00-") is None)
  assert_true(
    @propagation.parse_traceparent(
      "00-00000000000000000000000000000000-00f067aa0ba902b7-01",
    ) is None,
  )
  assert_true(
    @propagation.parse_traceparent(
      "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-0000000000000000-01",
    ) is None,
  )
  assert_true(
    @propagation.parse_traceparent(
      "ff-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01",
    ) is None,
  )
  assert_true(
    @propagation.parse_traceparent(
      "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-0g",
    ) is None,
  )
  assert_true(
    @propagation.parse_traceparent(
      "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01-x",
    ) is None,
  )
  match
    @propagation.parse_traceparent(
      "01-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01-x",
    ) {
    Some(sc) => assert_true(sc.is_valid())
    None => fail("future version with extra fields should parse")
  }
  assert_true(
    @propagation.parse_traceparent(
      "01-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01x",
    ) is None,
  )
}

test "scratch_format_traceparent_flags_masked" {
  let sc = @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    0x1FF,
  )
  assert_eq(
    @propagation.format_traceparent(sc),
    "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-ff",
  )
}

test "scratch_tracestate_multi_tenant_key" {
  match @propagation.parse_tracestate("a@b=1") {
    Some(v) => assert_eq(v, "a@b=1")
    None => fail("valid multi-tenant key rejected")
  }
  match @propagation.parse_tracestate("1a@b=1") {
    Some(v) => assert_eq(v, "1a@b=1")
    None => fail("tenant id may start with digit")
  }
  assert_true(@propagation.parse_tracestate("@b=1") is None)
  assert_true(@propagation.parse_tracestate("a@=1") is None)
  assert_true(@propagation.parse_tracestate("a@b@c=1") is None)
}

test "scratch_percent_decode_plain" {
  assert_eq(@propagation.percent_decode("abc"), Some("abc"))
  assert_eq(@propagation.percent_decode(""), Some(""))
  assert_eq(@propagation.percent_decode("a b"), None)
  assert_eq(@propagation.percent_decode("a,b"), None)
  assert_eq(@propagation.percent_decode("%41%42"), Some("AB"))
  assert_eq(@propagation.percent_decode("%4a"), Some("J"))
}

test "scratch_baggage_parse_properties_ignored" {
  assert_eq(
    @propagation.parse_baggage("a=1;prop=2,b=3;flag"),
    [("a", "1"), ("b", "3")],
  )
  assert_eq(@propagation.parse_baggage("a=1,b=2,"), [("a", "1"), ("b", "2")])
  assert_eq(@propagation.parse_baggage("=1"), [])
  assert_eq(@propagation.parse_baggage("a"), [])
  assert_eq(@propagation.parse_baggage("a=1,,b=2"), [("a", "1"), ("b", "2")])
  assert_eq(@propagation.parse_baggage("a=%zz"), [])
}

test "scratch_format_baggage_roundtrip_unicode" {
  let entries = [("k", "héllo😀 world"), ("a b", "ignored")]
  let header = @propagation.format_baggage(entries)
  let parsed = @propagation.parse_baggage(header)
  assert_eq(parsed, [("k", "héllo😀 world")])
}
