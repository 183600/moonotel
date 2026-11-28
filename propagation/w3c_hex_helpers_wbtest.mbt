// White-box tests for the W3C traceparent hex helpers. `format_traceparent`
// currently calls them with the fixed 16/8-byte ID lengths, but the helpers
// document support for any byte count; these tests pin the short-run tail
// paths and the out-of-range canonicalization they share with `bytes_to_hex`.

///|
fn write_hex_for_test(bytes : Array[Int32]) -> String {
  let byte_count = bytes.length()
  let out = FixedArray::make(byte_count * 4, b'\x00')
  write_hex(out, 0, bytes, byte_count)
  out.unsafe_reinterpret_as_bytes().to_unchecked_string()
}

///|
test "write_hex_tail_paths_match_bytes_to_hex" {
  for
    bytes in [
      [0x0f],
      [0x10, 0xab],
      [0x01, 0x23, 0x45],
      [0x01, 0x02, 0x03, 0x04, 0x05],
      [0x10, 0x20, 0x30, 0x40, 0x50, 0x60],
      [0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10],
    ] {
    assert_eq(write_hex_for_test(bytes), @api.bytes_to_hex(bytes))
  }
}

///|
test "write_hex_tail_paths_canonicalize_out_of_range_bytes" {
  let bytes = [0x101, -1, 0x100, 256, -16, 0x1ff, 0x100]
  assert_eq(write_hex_for_test(bytes), @api.bytes_to_hex(bytes))
}

///|
test "decode_hex_nonzero_tail_paths_decode_short_runs" {
  for
    pair in [
      ("0f", [0x0f]),
      ("10ab", [0x10, 0xab]),
      ("012345", [0x01, 0x23, 0x45]),
      ("0102030405", [0x01, 0x02, 0x03, 0x04, 0x05]),
      ("102030405060", [0x10, 0x20, 0x30, 0x40, 0x50, 0x60]),
      ("0a0b0c0d0e0f10", [0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10]),
    ] {
    let (text, expected) = pair
    assert_eq(decode_hex_nonzero(text, 0, expected.length()), Some(expected))
  }
}

///|
test "decode_hex_nonzero_tail_paths_reject_bad_or_zero_bytes" {
  assert_eq(decode_hex_nonzero("00", 0, 1), None)
  assert_eq(decode_hex_nonzero("zz", 0, 1), None)
  assert_eq(decode_hex_nonzero("0000", 0, 2), None)
  assert_eq(decode_hex_nonzero("000000", 0, 3), None)
  assert_eq(decode_hex_nonzero("0000ff", 0, 3), Some([0, 0, 0xff]))
  assert_eq(decode_hex_nonzero("xx0f", 2, 1), Some([0x0f]))
}
