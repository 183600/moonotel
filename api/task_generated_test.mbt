
test "span_context_trace_flags_edge_cases" {
  let trace_id = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  let span_id = [2, 2, 2, 2, 2, 2, 2, 2]
  
  let sc1 = span_context(trace_id, span_id, 0)
  assert_false(sc1.is_sampled())
  
  let sc2 = span_context(trace_id, span_id, 1)
  assert_true(sc2.is_sampled())
  
  let sc3 = span_context(trace_id, span_id, 255)
  assert_true(sc3.is_sampled())
  
  let sc4 = span_context(trace_id, span_id, 254)
  assert_false(sc4.is_sampled())
}

test "span_context_validation_boundary" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  
  // All zeros is invalid
  let sc1 = span_context(trace_id, span_id, 1)
  assert_false(sc1.is_valid())
  
  // One non-zero in trace_id
  let trace_id2 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let sc2 = span_context(trace_id2, span_id, 1)
  assert_false(sc2.is_valid()) // span_id still zero
  
  // One non-zero in span_id
  let span_id2 = [0, 0, 0, 0, 0, 0, 0, 1]
  let sc3 = span_context(trace_id, span_id2, 1)
  assert_false(sc3.is_valid()) // trace_id still zero
  
  // Both non-zero
  let sc4 = span_context(trace_id2, span_id2, 1)
  assert_true(sc4.is_valid())
}

test "bytes_to_hex_consistency" {
  let bytes = [0, 1, 15, 16, 255]
  let hex = bytes_to_hex(bytes)
  assert_eq(hex, "00010f10ff")
}

test "span_context_id_lengths" {
  let trace_id_short = [1, 2, 3]
  let span_id_ok = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc1 = span_context(trace_id_short, span_id_ok, 1)
  assert_false(sc1.is_valid())
  
  let trace_id_ok = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id_short = [1, 2, 3]
  let sc2 = span_context(trace_id_ok, span_id_short, 1)
  assert_false(sc2.is_valid())
}

test "is_zero_helper" {
  assert_true(is_zero([0, 0, 0, 0]))
  assert_false(is_zero([0, 1, 0, 0]))
  assert_false(is_zero([1, 0, 0, 0]))
  assert_false(is_zero([0, 0, 0, 1]))
  assert_true(is_zero([]))
}

test "byte_to_hex_char_values" {
  assert_eq(byte_to_hex_char(0), "0")
  assert_eq(byte_to_hex_char(9), "9")
  assert_eq(byte_to_hex_char(10), "a")
  assert_eq(byte_to_hex_char(15), "f")
  assert_eq(byte_to_hex_char(16), "0") // Default case
}

test "invalid_span_context_properties" {
  let sc = invalid_span_context()
  assert_false(sc.is_valid())
  assert_false(sc.is_sampled())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
}

test "hex_char_to_int_extra" {
  assert_eq(hex_char_to_int('0'), 0)
  assert_eq(hex_char_to_int('5'), 5)
  assert_eq(hex_char_to_int('9'), 9)
  assert_eq(hex_char_to_int('a'), 10)
  assert_eq(hex_char_to_int('f'), 15)
  assert_eq(hex_char_to_int('A'), 10)
  assert_eq(hex_char_to_int('F'), 15)
  assert_eq(hex_char_to_int('z'), 0)
}

test "hex_to_bytes_extra" {
  let hex = "00010f10ff"
  let bytes = hex_to_bytes(hex)
  assert_eq(bytes.length(), 5)
  assert_eq(bytes[0], 0)
  assert_eq(bytes[1], 1)
  assert_eq(bytes[2], 15)
  assert_eq(bytes[3], 16)
  assert_eq(bytes[4], 255)
}

test "hex_to_int_extra" {
  assert_eq(hex_to_int("0"), 0)
  assert_eq(hex_to_int("ff"), 255)
  assert_eq(hex_to_int("100"), 256)
}

test "tracer_creation_and_properties" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  assert_eq(tracer.name, "test-tracer")
  assert_eq(tracer.provider.service_name, "test-service")
}

test "span_creation_and_properties" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span = tracer.start_span("test-span")
  assert_eq(span.name, "test-span")
  assert_true(span.context.is_valid())
}

test "multiple_tracers_from_same_provider" {
  let provider = create_tracer_provider("test-service")
  let tracer1 = create_tracer(provider, "tracer-1")
  let tracer2 = create_tracer(provider, "tracer-2")
  assert_eq(tracer1.provider.service_name, tracer2.provider.service_name)
}

test "sampler_ratio_detailed_parity" {
  // Ratio 0.5 uses parity of first byte
  assert_true(sampler_ratio([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 0.5).is_sampled)
  assert_false(sampler_ratio([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 0.5).is_sampled)
  assert_true(sampler_ratio([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 0.5).is_sampled)
  assert_false(sampler_ratio([3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 0.5).is_sampled)
}

test "sampler_parent_based_root_samples_detailed" {
  let invalid_ctx = invalid_span_context()
  
  let d1 = sampler_parent_based(invalid_ctx, true)
  assert_true(d1.is_sampled)
  assert_true(d1.is_recorded)
  
  let d2 = sampler_parent_based(invalid_ctx, false)
  assert_false(d2.is_sampled)
  assert_false(d2.is_recorded)
}

test "sampler_always_on_detailed" {
  let d = sampler_always_on([1, 2, 3])
  assert_true(d.is_sampled)
  assert_true(d.is_recorded)
}

test "sampler_always_off_detailed" {
  let d = sampler_always_off([1, 2, 3])
  assert_false(d.is_sampled)
  assert_false(d.is_recorded)
}

test "span_context_hex_lowercase" {
  let trace_id = [0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19]
  let span_id = [0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11]
  let sc = span_context(trace_id, span_id, 1)
  assert_eq(sc.trace_id_hex(), "0a0b0c0d0e0f10111213141516171819")
  assert_eq(sc.span_id_hex(), "0a0b0c0d0e0f1011")
}

test "is_zero_edge_cases" {
  assert_true(is_zero([]))
  assert_true(is_zero([0]))
  assert_false(is_zero([1]))
  assert_false(is_zero([0, 0, 1]))
}
