// White-box tests for baggage helper functions whose equal and out-of-range
// inputs are not produced by the public formatting paths but are part of the
// documented helper contracts.

///|
test "compare_baggage_keys_orders_prefixes_and_equal_keys" {
  assert_eq(compare_baggage_keys("a", "a"), 0)
  assert_eq(compare_baggage_keys("", ""), 0)
  assert_eq(compare_baggage_keys("", "a"), -1)
  assert_eq(compare_baggage_keys("a", "ab"), -1)
  assert_eq(compare_baggage_keys("ab", "a"), 1)
  assert_eq(compare_baggage_keys("A", "a"), -1)
}

///|
test "upper_hex_byte_renders_nibbles_and_falls_back_to_zero" {
  assert_eq(upper_hex_byte(0), b'0')
  assert_eq(upper_hex_byte(9), b'9')
  assert_eq(upper_hex_byte(10), b'A')
  assert_eq(upper_hex_byte(15), b'F')
  assert_eq(upper_hex_byte(16), b'0')
  assert_eq(upper_hex_byte(-1), b'0')
  assert_eq(upper_hex_byte(256), b'0')
}
