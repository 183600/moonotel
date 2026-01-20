// Additional edge-case and property-style tests for SpanContext helpers

fn nibble_to_hex_char(n : Int) -> String {
  if n == 0 { "0" }
  else if n == 1 { "1" }
  else if n == 2 { "2" }
  else if n == 3 { "3" }
  else if n == 4 { "4" }
  else if n == 5 { "5" }
  else if n == 6 { "6" }
  else if n == 7 { "7" }
  else if n == 8 { "8" }
  else if n == 9 { "9" }
  else if n == 10 { "a" }
  else if n == 11 { "b" }
  else if n == 12 { "c" }
  else if n == 13 { "d" }
  else if n == 14 { "e" }
  else if n == 15 { "f" }
  else { "0" }
}

fn expected_hex_byte(b : Int) -> String {
  let high = (b >> 4) & 0x0F
  let low = b & 0x0F
  nibble_to_hex_char(high) + nibble_to_hex_char(low)
}

test "bytes_to_hex_empty" {
  assert_eq(bytes_to_hex([]), "")
}

test "bytes_to_hex_single_byte_roundtrip_0_255" {
  let mut b = 0
  while b < 256 {
    let got = bytes_to_hex([b])
    assert_eq(got.length(), 2)
    assert_eq(got, expected_hex_byte(b))
    b = b + 1
  }
}

test "is_zero_empty_is_true" {
  assert_true(is_zero([]))
}

test "span_context_invalid_trace_id_wrong_length" {
  let trace_id = Array::make(15, 1)
  let span_id = Array::make(8, 1)
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_invalid_span_id_wrong_length" {
  let trace_id = Array::make(16, 1)
  let span_id = Array::make(7, 1)
  let sc = span_context(trace_id, span_id, 1)
  assert_false(sc.is_valid())
}

test "span_context_valid_minimal_nonzero_ids" {
  let trace_id = Array::make(16, 0)
  trace_id[15] = 1

  let span_id = Array::make(8, 0)
  span_id[7] = 1

  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000001")
  assert_eq(sc.span_id_hex(), "0000000000000001")
}
