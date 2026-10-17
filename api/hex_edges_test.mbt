// Hex helpers handle out-of-range bytes defensively.

test "bytes_to_hex_masks_out_of_range_bytes" {
  assert_eq(@api.bytes_to_hex([999, -1]), "070f")
}

test "bytes_from_hex_rejects_non_ascii_characters" {
  assert_true(@api.bytes_from_hex("éé") is None)
}
