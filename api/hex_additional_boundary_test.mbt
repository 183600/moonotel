// Additional hex encoding tests for boundary values and special cases

test "hex_boundary_values" {
  // Test boundary values at 8-bit limits
  assert_eq(bytes_to_hex([0x00]), "00")
  assert_eq(bytes_to_hex([0xFF]), "ff")
  assert_eq(bytes_to_hex([0x7F]), "7f")
  assert_eq(bytes_to_hex([0x80]), "80")
}

test "hex_sequential_patterns" {
  // Test sequential byte patterns
  assert_eq(bytes_to_hex([0x01, 0x02, 0x03, 0x04]), "01020304")
  assert_eq(bytes_to_hex([0x10, 0x20, 0x30, 0x40]), "10203040")
}

test "hex_power_of_two" {
  // Test powers of two
  assert_eq(bytes_to_hex([1]), "01")
  assert_eq(bytes_to_hex([2]), "02")
  assert_eq(bytes_to_hex([4]), "04")
  assert_eq(bytes_to_hex([8]), "08")
  assert_eq(bytes_to_hex([16]), "10")
  assert_eq(bytes_to_hex([32]), "20")
  assert_eq(bytes_to_hex([64]), "40")
  assert_eq(bytes_to_hex([128]), "80")
}

test "hex_complementary_values" {
  // Test complementary bit patterns
  assert_eq(bytes_to_hex([0xAA]), "aa")
  assert_eq(bytes_to_hex([0x55]), "55")
  assert_eq(bytes_to_hex([0xFF]), "ff")
  assert_eq(bytes_to_hex([0x00]), "00")
}

test "hex_word_boundary" {
  // Test word boundary patterns
  assert_eq(bytes_to_hex([0x00, 0x01]), "0001")
  assert_eq(bytes_to_hex([0xFF, 0xFE]), "fffe")
  assert_eq(bytes_to_hex([0x80, 0x00]), "8000")
}

test "hex_dword_boundary" {
  // Test dword boundary patterns
  assert_eq(bytes_to_hex([0x00, 0x00, 0x00, 0x01]), "00000001")
  assert_eq(bytes_to_hex([0xFF, 0xFF, 0xFF, 0xFF]), "ffffffff")
  assert_eq(bytes_to_hex([0x80, 0x00, 0x00, 0x00]), "80000000")
}

test "hex_negative_interpretation" {
  // Test bytes that could be interpreted as negative
  assert_eq(bytes_to_hex([0x80]), "80")
  assert_eq(bytes_to_hex([0xFF]), "ff")
  assert_eq(bytes_to_hex([0x81]), "81")
}

test "hex_min_max_alternation" {
  // Test alternating min/max values
  assert_eq(bytes_to_hex([0x00, 0xFF, 0x00, 0xFF]), "00ff00ff")
  assert_eq(bytes_to_hex([0xFF, 0x00, 0xFF, 0x00]), "ff00ff00")
}

test "hex_fibonacci_sequence" {
  // Test Fibonacci sequence values
  assert_eq(bytes_to_hex([1, 1, 2, 3, 5, 8, 13, 21]), "0101020305080d15")
}

test "hex_mixed_case_output" {
  // Ensure all output is lowercase as per specification
  let hex_upper = bytes_to_hex([0xAB, 0xCD, 0xEF])
  assert_eq(hex_upper, "abcdef")
}
