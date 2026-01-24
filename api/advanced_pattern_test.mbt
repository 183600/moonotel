// Advanced pattern-based tests for comprehensive coverage

// Bit manipulation tests for trace flags
test "trace_flags_bit_pattern_0b00000001" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0b00000001)
  assert_true(sc.is_sampled())
}

test "trace_flags_bit_pattern_0b00000010" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0b00000010)
  assert_false(sc.is_sampled())
}

test "trace_flags_bit_pattern_0b00000100" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0b00000100)
  assert_false(sc.is_sampled())
}

test "trace_flags_bit_pattern_0b00001000" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0b00001000)
  assert_false(sc.is_sampled())
}

test "trace_flags_bit_pattern_0b00010000" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0b00010000)
  assert_false(sc.is_sampled())
}

test "trace_flags_bit_pattern_0b00100000" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0b00100000)
  assert_false(sc.is_sampled())
}

test "trace_flags_bit_pattern_0b01000000" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0b01000000)
  assert_false(sc.is_sampled())
}

test "trace_flags_bit_pattern_0b10000000" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0b10000000)
  assert_false(sc.is_sampled())
}

test "trace_flags_bit_pattern_0b11111111" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0b11111111)
  assert_true(sc.is_sampled())
}

test "trace_flags_bit_pattern_0b10101010" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0b10101010)
  assert_false(sc.is_sampled())
}

test "trace_flags_bit_pattern_0b01010101" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0b01010101)
  assert_true(sc.is_sampled())
}

// Prime number patterns in IDs
test "trace_id_first_16_primes" {
  let trace_id = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53]
  let span_id = [2, 3, 5, 7, 11, 13, 17, 19]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_id_first_8_primes" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [2, 3, 5, 7, 11, 13, 17, 19]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "020305070b0d1113")
}

// Checkerboard patterns
test "trace_id_checkerboard_1" {
  let trace_id = [0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55]
  let span_id = [0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "trace_id_checkerboard_2" {
  let trace_id = [0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA]
  let span_id = [0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

// Mirrored patterns
test "trace_id_mirror_simple" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 8, 7, 6, 5, 4, 3, 2, 1]
  let span_id = [1, 2, 3, 4, 4, 3, 2, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_id_mirror_values" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [10, 20, 30, 40, 40, 30, 20, 10]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

// Geometric sequences
test "trace_id_powers_of_two_full" {
  let trace_id = [1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128]
  let span_id = [1, 2, 4, 8, 16, 32, 64, 128]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_id_doubling_sequence" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 2, 4, 8, 16, 32, 64, 128]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0102040810204080")
}

// ASCII-like patterns
test "trace_id_printable_ascii_start" {
  let trace_id = [32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47]
  let span_id = [48, 49, 50, 51, 52, 53, 54, 55]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_id_digit_ascii_codes" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [48, 49, 50, 51, 52, 53, 54, 55]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "3031323334353637")
}

// Modulo patterns
test "trace_id_mod_16_sequence" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_id_mod_256_wrapping" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [248, 249, 250, 251, 252, 253, 254, 255]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "f8f9fafbfcfdfeff")
}

// Byte position specific tests
test "trace_id_nonzero_at_position_0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex().length(), 32)
}

test "trace_id_nonzero_at_position_15" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000001")
}

test "trace_id_nonzero_at_position_7" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 99, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000630000000000000000")
}

test "span_id_nonzero_at_position_0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [77, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "4d00000000000000")
}

test "span_id_nonzero_at_position_7" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 88]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_eq(sc.span_id_hex(), "0000000000000058")
}

// Multiple validity checks in sequence
test "span_context_sequence_valid_invalid_valid" {
  let trace_id1 = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id1 = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc1 = span_context(trace_id1, span_id1, 0)
  assert_true(sc1.is_valid())
  
  let trace_id2 = Array::make(16, 0)
  let span_id2 = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc2 = span_context(trace_id2, span_id2, 0)
  assert_false(sc2.is_valid())
  
  let trace_id3 = [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id3 = [2, 0, 0, 0, 0, 0, 0, 0]
  let sc3 = span_context(trace_id3, span_id3, 0)
  assert_true(sc3.is_valid())
}

// Hex encoding edge cases
test "bytes_to_hex_0x00_to_0x10" {
  let bytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  assert_eq(bytes_to_hex(bytes), "000102030405060708090a0b0c0d0e0f10")
}

test "bytes_to_hex_multiples_of_17" {
  let bytes = [0, 17, 34, 51, 68, 85, 102, 119]
  assert_eq(bytes_to_hex(bytes), "0011223344556677")
}

test "bytes_to_hex_0xF0_through_0xFF" {
  let bytes = [240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255]
  assert_eq(bytes_to_hex(bytes), "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
}

// Complex is_zero tests
test "is_zero_255_zeros" {
  let arr = Array::make(255, 0)
  assert_true(is_zero(arr))
}

test "is_zero_255_with_one_at_end" {
  let arr = Array::make(255, 0)
  arr[254] = 1
  assert_false(is_zero(arr))
}

test "is_zero_255_with_one_at_start" {
  let arr = Array::make(255, 0)
  arr[0] = 1
  assert_false(is_zero(arr))
}

test "is_zero_255_with_one_in_middle" {
  let arr = Array::make(255, 0)
  arr[127] = 1
  assert_false(is_zero(arr))
}

// Sampling flag with various ID patterns
test "sampled_with_ascending_ids" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_sampled())
  assert_true(sc.is_valid())
}

test "not_sampled_with_descending_ids" {
  let trace_id = [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  let span_id = [8, 7, 6, 5, 4, 3, 2, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_sampled())
  assert_true(sc.is_valid())
}

test "sampled_with_max_values" {
  let trace_id = Array::make(16, 255)
  let span_id = Array::make(8, 255)
  let sc = span_context(trace_id, span_id, 255)
  assert_true(sc.is_sampled())
  assert_true(sc.is_valid())
}

// Invalid contexts with various lengths
test "invalid_trace_id_length_0" {
  let trace_id : Array[Int] = []
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "invalid_span_id_length_0" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id : Array[Int] = []
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

test "invalid_both_ids_length_0" {
  let trace_id : Array[Int] = []
  let span_id : Array[Int] = []
  let sc = span_context(trace_id, span_id, 0)
  assert_false(sc.is_valid())
}

// Hex with repeating byte patterns
test "bytes_to_hex_all_0x12" {
  let bytes = Array::make(10, 0x12)
  assert_eq(bytes_to_hex(bytes), "12121212121212121212")
}

test "bytes_to_hex_all_0xAB" {
  let bytes = Array::make(8, 0xAB)
  assert_eq(bytes_to_hex(bytes), "abababababababab")
}

test "bytes_to_hex_all_0x00" {
  let bytes = Array::make(16, 0)
  assert_eq(bytes_to_hex(bytes), "00000000000000000000000000000000")
}

// Complex span context scenarios
test "span_context_min_valid_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [1, 0, 0, 0, 0, 0, 0, 0]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_context_min_valid_span_id" {
  let trace_id = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

test "span_context_both_ids_min_valid" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
}

// byte_to_hex_char edge cases
test "byte_to_hex_char_large_negative" {
  assert_eq(byte_to_hex_char(-100), "0")
}

test "byte_to_hex_char_large_positive" {
  assert_eq(byte_to_hex_char(1000), "0")
}

test "byte_to_hex_char_17" {
  assert_eq(byte_to_hex_char(17), "0")
}

test "byte_to_hex_char_32" {
  assert_eq(byte_to_hex_char(32), "0")
}
