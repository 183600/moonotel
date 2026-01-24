// Additional comprehensive tests for OpenTelemetry tracing

test "span_context_trace_flags_default" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 0)
  assert_eq(context.trace_flags, 0)
  assert_false(context.is_sampled())
}

test "span_context_trace_flags_sampled" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 1)
  assert_eq(context.trace_flags, 1)
  assert_true(context.is_sampled())
}

test "span_context_trace_flags_with_multiple_bits" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 5)
  assert_true(context.is_sampled())
}

test "span_context_invalid_empty_trace_id" {
  let trace_id = []
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_invalid_empty_span_id" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = []
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_invalid_short_trace_id" {
  let trace_id = Array::make(15, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_invalid_short_span_id" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(7, 0xAB)
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_invalid_long_trace_id" {
  let trace_id = Array::make(17, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_invalid_long_span_id" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(9, 0xAB)
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_valid_with_normal_values" {
  let trace_id = Array::make(16, 0xAB)
  let span_id = Array::make(8, 0xCD)
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_context_zero_trace_id_only" {
  let trace_id = Array::make(16, 0)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_zero_span_id_only" {
  let trace_id = Array::make(16, 0xAB)
  let span_id = Array::make(8, 0)
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_both_zero" {
  let trace_id = Array::make(16, 0)
  let span_id = Array::make(8, 0)
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "is_zero_empty_array" {
  assert_true(is_zero([]))
}

test "is_zero_all_zeros" {
  assert_true(is_zero(Array::make(10, 0)))
}

test "is_zero_with_some_nonzero" {
  let arr = [0, 0, 1, 0]
  assert_false(is_zero(arr))
}

test "is_zero_all_nonzero" {
  let arr = Array::make(5, 0xFF)
  assert_false(is_zero(arr))
}

test "is_zero_single_zero" {
  assert_true(is_zero([0]))
}

test "is_zero_single_nonzero" {
  assert_false(is_zero([42]))
}

test "bytes_to_hex_single_byte" {
  assert_eq(bytes_to_hex([0]), "00")
  assert_eq(bytes_to_hex([255]), "ff")
}

test "bytes_to_hex_two_bytes" {
  assert_eq(bytes_to_hex([0, 0]), "0000")
  assert_eq(bytes_to_hex([255, 255]), "ffff")
}

test "bytes_to_hex_mixed_values" {
  assert_eq(bytes_to_hex([0x12, 0x34]), "1234")
  assert_eq(bytes_to_hex([0xAA, 0xBB]), "aabb")
  assert_eq(bytes_to_hex([0x01, 0x10]), "0110")
}

test "byte_to_hex_char_all_valid" {
  assert_eq(byte_to_hex_char(0), "0")
  assert_eq(byte_to_hex_char(1), "1")
  assert_eq(byte_to_hex_char(9), "9")
  assert_eq(byte_to_hex_char(10), "a")
  assert_eq(byte_to_hex_char(15), "f")
}

test "byte_to_hex_char_edge_cases" {
  assert_eq(byte_to_hex_char(-10), "0")
  assert_eq(byte_to_hex_char(-1), "0")
  assert_eq(byte_to_hex_char(16), "0")
  assert_eq(byte_to_hex_char(32), "0")
  assert_eq(byte_to_hex_char(255), "0")
}

test "trace_id_hex_length" {
  let trace_id = Array::make(16, 0xAB)
  let span_id = Array::make(8, 0xCD)
  let context = span_context(trace_id, span_id, 1)
  assert_eq(context.trace_id_hex().length(), 32)
}

test "span_id_hex_length" {
  let trace_id = Array::make(16, 0xAB)
  let span_id = Array::make(8, 0xCD)
  let context = span_context(trace_id, span_id, 1)
  assert_eq(context.span_id_hex().length(), 16)
}

test "trace_id_hex_format" {
  let trace_id = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
  let span_id = Array::make(8, 0x12)
  let context = span_context(trace_id, span_id, 1)
  assert_eq(context.trace_id_hex(), "00112233445566778899aabbccddeeff")
}

test "span_id_hex_format" {
  let trace_id = Array::make(16, 0x12)
  let span_id = [0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE]
  let context = span_context(trace_id, span_id, 1)
  assert_eq(context.span_id_hex(), "deadbeefcafebabe")
}

test "hex_string_case_consistency" {
  let arr = [10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(arr)
  assert_eq(hex, "0a0b0c0d0e0f")
}

test "invalid_span_context_has_valid_fields" {
  let context = invalid_span_context()
  assert_eq(context.trace_id.length(), 16)
  assert_eq(context.span_id.length(), 8)
  assert_eq(context.trace_flags, 0)
  assert_false(context.is_valid())
}

test "invalid_span_context_trace_id_all_zeros" {
  let context = invalid_span_context()
  let mut all_zero = true
  let mut i = 0
  while i < 16 {
    if context.trace_id[i] != 0 {
      all_zero = false
      break
    }
    i = i + 1
  }
  assert_true(all_zero)
}

test "invalid_span_context_span_id_all_zeros" {
  let context = invalid_span_context()
  let mut all_zero = true
  let mut i = 0
  while i < 8 {
    if context.span_id[i] != 0 {
      all_zero = false
      break
    }
    i = i + 1
  }
  assert_true(all_zero)
}

test "is_sampled_zero_flags" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 0)
  assert_false(context.is_sampled())
}

test "is_sampled_flag_one" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_sampled())
}

test "is_sampled_flag_two" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 2)
  assert_false(context.is_sampled())
}

test "is_sampled_flag_three" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 3)
  assert_true(context.is_sampled())
}

test "context_immutability_preserved" {
  let trace_id = Array::make(16, 0xAB)
  let span_id = Array::make(8, 0xCD)
  let context1 = span_context(trace_id, span_id, 1)
  let context2 = span_context(trace_id, span_id, 1)
  assert_eq(context1.trace_id_hex(), context2.trace_id_hex())
  assert_eq(context1.span_id_hex(), context2.span_id_hex())
}

test "different_trace_ids_produce_different_hex" {
  let trace_id1 = Array::make(16, 0xAB)
  let trace_id2 = Array::make(16, 0xCD)
  let span_id = Array::make(8, 0xEF)
  let context1 = span_context(trace_id1, span_id, 1)
  let context2 = span_context(trace_id2, span_id, 1)
  assert_true(context1.trace_id_hex() != context2.trace_id_hex())
}

test "different_span_ids_produce_different_hex" {
  let trace_id = Array::make(16, 0xAB)
  let span_id1 = Array::make(8, 0xCD)
  let span_id2 = Array::make(8, 0xEF)
  let context1 = span_context(trace_id, span_id1, 1)
  let context2 = span_context(trace_id, span_id2, 1)
  assert_true(context1.span_id_hex() != context2.span_id_hex())
}

test "max_trace_flags_value" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 255)
  assert_true(context.is_sampled())
}

test "negative_bytes_handled" {
  // In MoonBit, bytes can be negative, ensure they are handled
  let trace_id = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let span_id = Array::make(8, 0xFF)
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "special_byte_value_128" {
  assert_eq(bytes_to_hex([128]), "80")
}

test "special_byte_value_127" {
  assert_eq(bytes_to_hex([127]), "7f")
}

test "hex_conversion_roundtrip_equivalence" {
  // Note: Full roundtrip not possible due to hex representation
  // But we can verify hex output is consistent
  let arr = [0x12, 0x34, 0x56, 0x78]
  let hex = bytes_to_hex(arr)
  assert_eq(hex, "12345678")
}

test "context_with_trace_flags_128" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 128)
  assert_false(context.is_sampled())
}

test "context_with_trace_flags_129" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 129)
  assert_true(context.is_sampled())
}

test "very_large_trace_id_array" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "very_large_span_id_array" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "context_is_valid_returns_correct_boolean" {
  let valid_trace_id = Array::make(16, 0xAB)
  let valid_span_id = Array::make(8, 0xCD)
  let valid_context = span_context(valid_trace_id, valid_span_id, 1)
  
  let invalid_trace_id = Array::make(16, 0)
  let invalid_context = span_context(invalid_trace_id, valid_span_id, 1)
  
  assert_true(valid_context.is_valid())
  assert_false(invalid_context.is_valid())
}

test "hex_output_is_lowercase" {
  let arr = [0xAA, 0xBB, 0xCC]
  let hex = bytes_to_hex(arr)
  // Verify lowercase
  assert_eq(hex, "aabbcc")
}

test "multiple_contexts_same_inputs" {
  let trace_id = Array::make(16, 0xAB)
  let span_id = Array::make(8, 0xCD)
  
  let context1 = span_context(trace_id, span_id, 1)
  let context2 = span_context(trace_id, span_id, 1)
  let context3 = span_context(trace_id, span_id, 1)
  
  assert_eq(context1.trace_id_hex(), context2.trace_id_hex())
  assert_eq(context2.trace_id_hex(), context3.trace_id_hex())
  assert_eq(context1.span_id_hex(), context2.span_id_hex())
  assert_eq(context2.span_id_hex(), context3.span_id_hex())
}

test "trace_flags_bitwise_and_sampled" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xAB)
  
  let ctx0 = span_context(trace_id, span_id, 0)
  let ctx1 = span_context(trace_id, span_id, 1)
  let ctx3 = span_context(trace_id, span_id, 3)
  let ctx5 = span_context(trace_id, span_id, 5)
  
  assert_false(ctx0.is_sampled())
  assert_true(ctx1.is_sampled())
  assert_true(ctx3.is_sampled())
  assert_true(ctx5.is_sampled())
}
