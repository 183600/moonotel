// Edge case validation tests for OpenTelemetry Tracing SDK

// Comprehensive hex encoding edge cases
test "hex_encoding_empty_array" {
  assert_eq!(bytes_to_hex([]), "")
}

test "hex_encoding_single_byte_min" {
  assert_eq!(bytes_to_hex([0x00]), "00")
  assert_eq!(bytes_to_hex([0x01]), "01")
  assert_eq!(bytes_to_hex([0x0F]), "0f")
}

test "hex_encoding_single_byte_max" {
  assert_eq!(bytes_to_hex([0xF0]), "f0")
  assert_eq!(bytes_to_hex([0xFF]), "ff")
  assert_eq!(bytes_to_hex([0x80]), "80")
  assert_eq!(bytes_to_hex([0x7F]), "7f")
}

test "hex_encoding_all_zeros" {
  let zeros = Array::make(10, 0x00)
  assert_eq!(bytes_to_hex(zeros), "00000000000000000000")
}

test "hex_encoding_all_ones" {
  let ones = Array::make(10, 0xFF)
  assert_eq!(bytes_to_hex(ones), "ffffffffffffffffffff")
}

test "hex_encoding_alternating_pattern" {
  let pattern = [0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55]
  assert_eq!(bytes_to_hex(pattern), "aa55aa55aa55")
}

test "hex_encoding_incrementing_sequence" {
  let seq = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
  assert_eq!(bytes_to_hex(seq), "00112233445566778899aabbccddeeff")
}

test "hex_encoding_bit_patterns" {
  assert_eq!(bytes_to_hex([0b10101010]), "aa")
  assert_eq!(bytes_to_hex([0b01010101]), "55")
  assert_eq!(bytes_to_hex([0b11110000]), "f0")
  assert_eq!(bytes_to_hex([0b00001111]), "0f")
}

test "hex_encoding_twos_complement_patterns" {
  assert_eq!(bytes_to_hex([0x80]), "80") // -128 in i8
  assert_eq!(bytes_to_hex([0xFF]), "ff") // -1 in i8
  assert_eq!(bytes_to_hex([0x81]), "81") // -127 in i8
  assert_eq!(bytes_to_hex([0xFE]), "fe") // -2 in i8
}

test "hex_encoding_palindromes" {
  assert_eq!(bytes_to_hex([0x12, 0x21]), "1221")
  assert_eq!(bytes_to_hex([0xAB, 0xBA]), "abba")
  assert_eq!(bytes_to_hex([0x01, 0x10]), "0110")
}

test "hex_encoding_large_array_length" {
  let large = Array::make(100, 0x42)
  let result = bytes_to_hex(large)
  assert_eq!(result.length(), 200)
  assert_eq!(result.substring(0, 2), "42")
}

test "byte_to_hex_char_boundaries" {
  assert_eq!(byte_to_hex_char(0), "0")
  assert_eq!(byte_to_hex_char(9), "9")
  assert_eq!(byte_to_hex_char(10), "a")
  assert_eq!(byte_to_hex_char(15), "f")
}

test "byte_to_hex_char_invalid_high_values" {
  assert_eq!(byte_to_hex_char(16), "0")
  assert_eq!(byte_to_hex_char(20), "0")
  assert_eq!(byte_to_hex_char(50), "0")
  assert_eq!(byte_to_hex_char(255), "0")
}

test "byte_to_hex_char_invalid_negative_values" {
  assert_eq!(byte_to_hex_char(-1), "0")
  assert_eq!(byte_to_hex_char(-10), "0")
  assert_eq!(byte_to_hex_char(-100), "0")
}

// Span context edge cases
test "span_context_valid_minimal_trace_id" {
  let trace_id = Array::make(16, 0x00)
  let span_id = Array::make(8, 0x01)
  let context = span_context(trace_id, span_id, 1)
  assert_true!(context.is_valid())
}

test "span_context_valid_maximal_trace_id" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0xFF)
  let context = span_context(trace_id, span_id, 1)
  assert_true!(context.is_valid())
}

test "span_context_unsampled_flag" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 0)
  assert_true!(context.is_valid())
  assert_false!(context.is_sampled())
}

test "span_context_sampled_flag" {
  let trace_id = [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  let span_id = [8, 7, 6, 5, 4, 3, 2, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true!(context.is_valid())
  assert_true!(context.is_sampled())
}

test "span_context_all_sample_flags" {
  let trace_id = Array::make(16, 0xAA)
  let span_id = Array::make(8, 0x55)
  let context = span_context(trace_id, span_id, 255)
  assert_true!(context.is_sampled())
}

test "span_context_trace_id_hex_length" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = Array::make(8, 0x00)
  let context = span_context(trace_id, span_id, 1)
  assert_eq!(context.trace_id_hex().length(), 32)
}

test "span_context_span_id_hex_length" {
  let trace_id = Array::make(16, 0x00)
  let span_id = Array::make(8, 0xFF)
  let context = span_context(trace_id, span_id, 1)
  assert_eq!(context.span_id_hex().length(), 16)
}

test "span_context_empty_trace_id_invalid" {
  let trace_id = []
  let span_id = Array::make(8, 0xFF)
  let context = span_context(trace_id, span_id, 1)
  assert_false!(context.is_valid())
}

test "span_context_empty_span_id_invalid" {
  let trace_id = Array::make(16, 0xFF)
  let span_id = []
  let context = span_context(trace_id, span_id, 1)
  assert_false!(context.is_valid())
}

// Tracer provider and tracer edge cases
test "tracer_provider_empty_service_name" {
  let provider = create_tracer_provider("")
  assert_eq!(provider.service_name, "")
}

test "tracer_provider_long_service_name" {
  let long_name = "".concat(
    "extremely-long-service-name-that-could-be-used-for-testing-",
    "edge-cases-in-trace-id-generation"
  )
  let provider = create_tracer_provider(long_name)
  assert_eq!(provider.service_name, long_name)
}

test "tracer_empty_name" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "")
  assert_eq!(tracer.name, "")
}

test "tracer_unique_spans_same_tracer" {
  let provider = create_tracer_provider("unique-service")
  let tracer = create_tracer(provider, "unique-tracer")
  let span1 = tracer.start_span("op1")
  let span2 = tracer.start_span("op2")
  assert_true!(span1.context.span_id_hex() != span2.context.span_id_hex())
}

test "tracer_span_names_preserved" {
  let provider = create_tracer_provider("name-test")
  let tracer = create_tracer(provider, "test-tracer")
  let span = tracer.start_span("very-specific-operation-name-for-testing")
  assert_eq!(span.name, "very-specific-operation-name-for-testing")
}

test "different_providers_unique_trace_ids" {
  let provider1 = create_tracer_provider("service-a")
  let tracer1 = create_tracer(provider1, "tracer-a")
  let span1 = tracer1.start_span("op")
  
  let provider2 = create_tracer_provider("service-bbbbb")
  let tracer2 = create_tracer(provider2, "tracer-b")
  let span2 = tracer2.start_span("op")
  
  assert_true!(span1.context.trace_id_hex() != span2.context.trace_id_hex())
}
