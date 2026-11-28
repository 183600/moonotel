// White-box tests for the SpanContext ID canonicalization helpers. They are
// shared by validation, serialization and ratio sampling, so the byte
// canonicalization and the odd-length tail of the all-zero check are pinned
// here independently of the fixed 16/8-byte public ID shape.

///|
test "serialized_id_byte_matches_bytes_to_hex_canonicalization" {
  for
    pair in [
      (0, 0),
      (255, 255),
      (256, 0),
      (257, 1),
      (0x101, 1),
      (-1, 15),
      (-16, 0),
      (0x1ff, 15),
    ] {
    let (value, expected) = pair
    assert_eq(serialized_id_byte(value), expected)
  }
}

///|
test "has_nonzero_byte_handles_odd_lengths_and_canonicalization" {
  assert_false(has_nonzero_byte([]))
  assert_true(has_nonzero_byte([1]))
  assert_true(has_nonzero_byte([0, 1]))
  assert_true(has_nonzero_byte([0, 0, 1]))
  assert_false(has_nonzero_byte([0, 0, 0]))
  assert_false(has_nonzero_byte([256]))
  assert_false(has_nonzero_byte([-16]))
  assert_true(has_nonzero_byte([-1]))
}
