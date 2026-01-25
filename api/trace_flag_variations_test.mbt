// Comprehensive trace flags testing

test "trace_flags_zero_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 0)
  assert_false(context.is_sampled())
}

test "trace_flags_one_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_sampled())
}

test "trace_flags_all_bits_set" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 255)
  assert_true(context.is_sampled())
}

test "trace_flags_even_numbers_not_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let context2 = span_context(trace_id, span_id, 2)
  assert_false(context2.is_sampled())
  
  let context4 = span_context(trace_id, span_id, 4)
  assert_false(context4.is_sampled())
  
  let context8 = span_context(trace_id, span_id, 8)
  assert_false(context8.is_sampled())
}

test "trace_flags_odd_numbers_sampled" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let context3 = span_context(trace_id, span_id, 3)
  assert_true(context3.is_sampled())
  
  let context5 = span_context(trace_id, span_id, 5)
  assert_true(context5.is_sampled())
  
  let context7 = span_context(trace_id, span_id, 7)
  assert_true(context7.is_sampled())
}

test "trace_flags_bit_masking" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let context_binary_1 = span_context(trace_id, span_id, 0b00000001)
  assert_true(context_binary_1.is_sampled())
  
  let context_binary_0 = span_context(trace_id, span_id, 0b00000000)
  assert_false(context_binary_0.is_sampled())
  
  let context_binary_all = span_context(trace_id, span_id, 0b11111111)
  assert_true(context_binary_all.is_sampled())
}

test "trace_flags_powers_of_two" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let context1 = span_context(trace_id, span_id, 1)
  assert_true(context1.is_sampled())
  
  let context2 = span_context(trace_id, span_id, 2)
  assert_false(context2.is_sampled())
  
  let context16 = span_context(trace_id, span_id, 16)
  assert_false(context16.is_sampled())
  
  let context128 = span_context(trace_id, span_id, 128)
  assert_false(context128.is_sampled())
}

test "trace_flags_combined_with_valid_context" {
  let trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let span_id = [11, 22, 33, 44, 55, 66, 77, 88]
  
  let context_sampled = span_context(trace_id, span_id, 1)
  assert_true(context_sampled.is_valid())
  assert_true(context_sampled.is_sampled())
  
  let context_not_sampled = span_context(trace_id, span_id, 0)
  assert_true(context_not_sampled.is_valid())
  assert_false(context_not_sampled.is_sampled())
}

test "trace_flags_with_invalid_context" {
  let invalid_ctx = invalid_span_context()
  assert_false(invalid_ctx.is_valid())
  assert_false(invalid_ctx.is_sampled())
}

test "trace_flags_sequential_values" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let mut i = 0
  while i < 256 {
    let context = span_context(trace_id, span_id, i)
    if i % 2 == 1 {
      assert_true(context.is_sampled())
    } else {
      assert_false(context.is_sampled())
    }
    i = i + 1
  }
}

test "trace_flags_w3c_spec_compliance" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let context_lsb_set = span_context(trace_id, span_id, 0b00000001)
  assert_true(context_lsb_set.is_sampled())
  
  let context_lsb_clear = span_context(trace_id, span_id, 0b11111110)
  assert_false(context_lsb_clear.is_sampled())
  
  let context_only_lsb = span_context(trace_id, span_id, 0b10000001)
  assert_true(context_only_lsb.is_sampled())
}

test "trace_flags_hex_values" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let context_0x00 = span_context(trace_id, span_id, 0x00)
  assert_false(context_0x00.is_sampled())
  
  let context_0x01 = span_context(trace_id, span_id, 0x01)
  assert_true(context_0x01.is_sampled())
  
  let context_0xFF = span_context(trace_id, span_id, 0xFF)
  assert_true(context_0xFF.is_sampled())
  
  let context_0xAA = span_context(trace_id, span_id, 0xAA)
  assert_false(context_0xAA.is_sampled())
  
  let context_0xAB = span_context(trace_id, span_id, 0xAB)
  assert_true(context_0xAB.is_sampled())
}

test "trace_flags_negative_like_values" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let context_127 = span_context(trace_id, span_id, 127)
  assert_true(context_127.is_sampled())
  
  let context_128 = span_context(trace_id, span_id, 128)
  assert_false(context_128.is_sampled())
  
  let context_129 = span_context(trace_id, span_id, 129)
  assert_true(context_129.is_sampled())
}

test "trace_flags_prime_numbers" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let context_3 = span_context(trace_id, span_id, 3)
  assert_true(context_3.is_sampled())
  
  let context_5 = span_context(trace_id, span_id, 5)
  assert_true(context_5.is_sampled())
  
  let context_7 = span_context(trace_id, span_id, 7)
  assert_true(context_7.is_sampled())
  
  let context_11 = span_context(trace_id, span_id, 11)
  assert_true(context_11.is_sampled())
  
  let context_13 = span_context(trace_id, span_id, 13)
  assert_true(context_13.is_sampled())
}

test "trace_flags_boundary_127_128" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  
  let context_126 = span_context(trace_id, span_id, 126)
  assert_false(context_126.is_sampled())
  
  let context_127 = span_context(trace_id, span_id, 127)
  assert_true(context_127.is_sampled())
  
  let context_128 = span_context(trace_id, span_id, 128)
  assert_false(context_128.is_sampled())
  
  let context_129 = span_context(trace_id, span_id, 129)
  assert_true(context_129.is_sampled())
}
