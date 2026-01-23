// Comprehensive hex encoding tests

test "hex_nibble_boundaries" {
  // Test each nibble value individually
  assert_eq(bytes_to_hex([0x00]), "00")
  assert_eq(bytes_to_hex([0x01]), "01")
  assert_eq(bytes_to_hex([0x0F]), "0f")
  assert_eq(bytes_to_hex([0x10]), "10")
  assert_eq(bytes_to_hex([0x1F]), "1f")
  assert_eq(bytes_to_hex([0xF0]), "f0")
  assert_eq(bytes_to_hex([0xFF]), "ff")
}

test "hex_multi_byte_sequences" {
  assert_eq(bytes_to_hex([0x00, 0x11, 0x22, 0x33]), "00112233")
  assert_eq(bytes_to_hex([0x44, 0x55, 0x66, 0x77]), "44556677")
  assert_eq(bytes_to_hex([0x88, 0x99, 0xAA, 0xBB]), "8899aabb")
  assert_eq(bytes_to_hex([0xCC, 0xDD, 0xEE, 0xFF]), "ccddeeff")
}

test "hex_palindrome_patterns" {
  assert_eq(bytes_to_hex([0x12, 0x21]), "1221")
  assert_eq(bytes_to_hex([0xAB, 0xBA]), "abba")
  assert_eq(bytes_to_hex([0xFF, 0xFF]), "ffff")
}

test "hex_alternating_high_low" {
  assert_eq(bytes_to_hex([0xF0, 0x0F]), "f00f")
  assert_eq(bytes_to_hex([0xA5, 0x5A]), "a55a")
  assert_eq(bytes_to_hex([0x3C, 0xC3]), "3cc3")
}

test "hex_all_same_nibble" {
  assert_eq(bytes_to_hex([0x11]), "11")
  assert_eq(bytes_to_hex([0x22]), "22")
  assert_eq(bytes_to_hex([0x33]), "33")
  assert_eq(bytes_to_hex([0x44]), "44")
  assert_eq(bytes_to_hex([0x55]), "55")
  assert_eq(bytes_to_hex([0x66]), "66")
  assert_eq(bytes_to_hex([0x77]), "77")
  assert_eq(bytes_to_hex([0x88]), "88")
  assert_eq(bytes_to_hex([0x99]), "99")
  assert_eq(bytes_to_hex([0xAA]), "aa")
  assert_eq(bytes_to_hex([0xBB]), "bb")
  assert_eq(bytes_to_hex([0xCC]), "cc")
  assert_eq(bytes_to_hex([0xDD]), "dd")
  assert_eq(bytes_to_hex([0xEE]), "ee")
}

test "hex_incrementing_pattern" {
  let pattern = [0, 1, 2, 3, 4, 5, 6, 7]
  assert_eq(bytes_to_hex(pattern), "0001020304050607")
}

test "hex_decrementing_pattern" {
  let pattern = [7, 6, 5, 4, 3, 2, 1, 0]
  assert_eq(bytes_to_hex(pattern), "0706050403020100")
}

test "hex_bit_shift_patterns" {
  assert_eq(bytes_to_hex([0b00000001]), "01")
  assert_eq(bytes_to_hex([0b00000010]), "02")
  assert_eq(bytes_to_hex([0b00000100]), "04")
  assert_eq(bytes_to_hex([0b00001000]), "08")
  assert_eq(bytes_to_hex([0b00010000]), "10")
  assert_eq(bytes_to_hex([0b00100000]), "20")
  assert_eq(bytes_to_hex([0b01000000]), "40")
  assert_eq(bytes_to_hex([0b10000000]), "80")
}

test "hex_prime_number_bytes" {
  assert_eq(bytes_to_hex([2]), "02")
  assert_eq(bytes_to_hex([3]), "03")
  assert_eq(bytes_to_hex([5]), "05")
  assert_eq(bytes_to_hex([7]), "07")
  assert_eq(bytes_to_hex([11]), "0b")
  assert_eq(bytes_to_hex([13]), "0d")
  assert_eq(bytes_to_hex([17]), "11")
  assert_eq(bytes_to_hex([19]), "13")
  assert_eq(bytes_to_hex([23]), "17")
  assert_eq(bytes_to_hex([29]), "1d")
  assert_eq(bytes_to_hex([31]), "1f")
}

test "hex_empty_array" {
  assert_eq(bytes_to_hex([]), "")
}

test "hex_very_long_array" {
  let long_array = Array::make(100, 0xAB)
  let hex = bytes_to_hex(long_array)
  assert_eq(hex.length(), 200)
}

test "byte_to_hex_char_invalid_values" {
  // Values outside 0-15 should return "0"
  assert_eq(byte_to_hex_char(16), "0")
  assert_eq(byte_to_hex_char(100), "0")
  assert_eq(byte_to_hex_char(255), "0")
  assert_eq(byte_to_hex_char(-1), "0")
}

test "hex_repeating_sequences" {
  assert_eq(bytes_to_hex([0x01, 0x01, 0x01, 0x01]), "01010101")
  assert_eq(bytes_to_hex([0xFF, 0xFF, 0xFF, 0xFF]), "ffffffff")
  assert_eq(bytes_to_hex([0x5A, 0x5A, 0x5A, 0x5A]), "5a5a5a5a")
}

test "hex_checksum_like_patterns" {
  assert_eq(bytes_to_hex([0xDE, 0xAD, 0xBE, 0xEF]), "deadbeef")
  assert_eq(bytes_to_hex([0xCA, 0xFE, 0xBA, 0xBE]), "cafebabe")
  assert_eq(bytes_to_hex([0xFE, 0xED, 0xFA, 0xCE]), "feedface")
}
