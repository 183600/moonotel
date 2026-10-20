// White-box tests for HTTP optional whitespace in baggage and tracestate.
// OWS is `SP / HTAB` only (RFC 9110 §5.6.3); CR and LF are not whitespace.

///|
test "is_ows_code_accepts_only_space_and_tab" {
  assert_true(is_ows_code(0x20))
  assert_true(is_ows_code(0x09))
  assert_false(is_ows_code(0x0A))
  assert_false(is_ows_code(0x0D))
  assert_false(is_ows_code(0x00))
  assert_false(is_ows_code(0x0B))
}

///|
test "tracestate_rejects_cr_and_lf_as_ows" {
  assert_eq(parse_tracestate("a=1\r"), None)
  assert_eq(parse_tracestate("a=1\n"), None)
  assert_eq(parse_tracestate("a=1\r\n"), None)
  assert_eq(parse_tracestate("\ra=1"), None)
  assert_eq(parse_tracestate("a=1,\rb=2"), None)
  assert_eq(parse_tracestate("a=1,\nb=2"), None)
  assert_eq(parse_tracestate("\ta=1\t"), Some("a=1"))
  assert_eq(parse_tracestate("a=1,\tb=2"), Some("a=1,b=2"))
  assert_true(Tracestate::parse("a=1\r") is None)
  assert_true(Tracestate::parse("a=1\n") is None)
  assert_true(Tracestate::parse("\ra=1") is None)
  assert_true(Tracestate::parse("a=1,\rb=2") is None)
  assert_eq(Tracestate::parse("\ta=1\t").unwrap().get("a"), Some("1"))
}

///|
test "baggage_rejects_cr_and_lf_as_ows" {
  assert_eq(parse_baggage("a=1\r"), [])
  assert_eq(parse_baggage("a=1\n"), [])
  assert_eq(parse_baggage("a=1\r\n"), [])
  assert_eq(parse_baggage("\ra=1"), [])
  assert_eq(parse_baggage("a=1\r,b=2"), [("b", "2")])
  assert_eq(parse_baggage("a=1,\rb=2"), [("a", "1")])
  assert_eq(parse_baggage_entries("a=1\r;p=2"), [])
  assert_eq(parse_baggage("\ta=1\t"), [("a", "1")])
  assert_eq(parse_baggage("a=1,\tb=2"), [("a", "1"), ("b", "2")])
}
