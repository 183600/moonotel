// Out-of-range ID elements are rendered like the low nibble of the byte, in
// both the single-byte and two-byte paths of `bytes_to_hex`. The result must
// stay consistent with groupable trace IDs and never contain a non-hex unit.

///|
test "bytes_to_hex_normalizes_out_of_range_elements" {
  assert_eq(@api.bytes_to_hex([-1]), "0f")
  assert_eq(@api.bytes_to_hex([256]), "00")
  assert_eq(@api.bytes_to_hex([0x1FF]), "0f")
  assert_eq(@api.bytes_to_hex([-1, -2]), "0f0e")
  assert_eq(@api.bytes_to_hex([256, 257]), "0001")
  assert_eq(@api.bytes_to_hex([1, 2]), "0102")
}
