// Tests for the W3C Baggage propagation limits: at most 64 members and
// 8192 bytes are propagated; members beyond either limit are dropped whole.

test "baggage_limit_constants_match_the_specification" {
  assert_eq(@propagation.BAGGAGE_MAX_MEMBERS, 64)
  assert_eq(@propagation.BAGGAGE_MAX_BYTES, 8192)
}

test "parse_baggage_keeps_at_most_64_members" {
  let sb = StringBuilder()
  let mut i = 0
  while i < 100 {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_string("k" + i.to_string())
    sb.write_char('=')
    sb.write_string(i.to_string())
    i = i + 1
  }
  let entries = @propagation.parse_baggage(sb.to_string())
  assert_eq(entries.length(), @propagation.BAGGAGE_MAX_MEMBERS)
  assert_eq(entries[0], ("k0", "0"))
  assert_eq(entries[63], ("k63", "63"))
}

test "format_baggage_emits_at_most_64_members" {
  let entries : Array[(String, String)] = []
  let mut i = 0
  while i < 100 {
    entries.push(("k" + i.to_string(), i.to_string()))
    i = i + 1
  }
  let header = @propagation.format_baggage(entries)
  let reparsed = @propagation.parse_baggage(header)
  assert_eq(reparsed.length(), @propagation.BAGGAGE_MAX_MEMBERS)
  assert_eq(reparsed[0], ("k0", "0"))
  assert_eq(reparsed[63], ("k63", "63"))
}

test "parse_baggage_drops_members_beyond_the_byte_budget" {
  let value = StringBuilder()
  let mut i = 0
  while i < 300 {
    value.write_char('v')
    i = i + 1
  }
  let sb = StringBuilder()
  let mut n = 0
  while n < 40 {
    if n > 0 {
      sb.write_char(',')
    }
    sb.write_string("k" + n.to_string())
    sb.write_char('=')
    sb.write_string(value.to_string())
    n = n + 1
  }
  let entries = @propagation.parse_baggage(sb.to_string())
  // k0 takes 303 bytes, k1..k9 take 304 each and k10.. take 305 each, so
  // exactly 26 members fit in the 8192-byte budget.
  assert_eq(entries.length(), 26)
  assert_eq(entries[0].0, "k0")
  assert_eq(entries[25].0, "k25")
  assert_true(
    @propagation.format_baggage(entries).length() <=
    @propagation.BAGGAGE_MAX_BYTES,
  )
}

test "parse_baggage_drops_a_member_larger_than_the_byte_budget" {
  let value = StringBuilder()
  let mut i = 0
  while i < 8200 {
    value.write_char('v')
    i = i + 1
  }
  assert_eq(@propagation.parse_baggage("k=" + value.to_string()), [])
}

test "format_baggage_drops_a_member_larger_than_the_byte_budget" {
  let value = StringBuilder()
  let mut i = 0
  while i < 8200 {
    value.write_char('v')
    i = i + 1
  }
  assert_eq(@propagation.format_baggage([("k", value.to_string())]), "")
}

test "format_baggage_keeps_a_member_that_exactly_fits" {
  // `k=` plus 8189 value characters is 8191 bytes, one byte below the limit.
  let value = StringBuilder()
  let mut i = 0
  while i < 8189 {
    value.write_char('v')
    i = i + 1
  }
  let header = @propagation.format_baggage([("k", value.to_string())])
  assert_eq(header.length(), 8191)
}

test "context_baggage_header_respects_the_member_limit" {
  let mut context = @context.Context::root()
  let mut i = 0
  while i < 100 {
    context = context.with_value("k" + i.to_string(), "v")
    i = i + 1
  }
  match @propagation.context_baggage_header(context) {
    Some(header) => {
      let parsed = @propagation.parse_baggage(header)
      assert_eq(parsed.length(), @propagation.BAGGAGE_MAX_MEMBERS)
    }
    None => fail("expected a baggage header")
  }
}

test "percent_encoded_length_matches_percent_encode" {
  let cases : Array[String] = [
    "", "abc", "a b", "100%", "a,b;c", "Am\u{00e9}lie", "\u{1F600}",
  ]
  for value in cases {
    assert_eq(
      @propagation.percent_encoded_length(value),
      @propagation.percent_encode(value).length(),
    )
  }
}
