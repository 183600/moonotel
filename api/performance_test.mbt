// Performance tests for SpanContext operations

test "span_context_creation_performance" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
}

test "hex_conversion_performance" {
  let trace_id = [255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240]
  let span_id = [239, 238, 237, 236, 235, 234, 233, 232]
  let sc = span_context(trace_id, span_id, 1)
  let hex = sc.trace_id_hex()
  assert_eq(hex.length(), 32)
}

test "multiple_context_creation" {
  let mut contexts = []
  let mut i = 0
  while i < 100 {
    let trace_id = [i, i+1, i+2, i+3, i+4, i+5, i+6, i+7, i+8, i+9, i+10, i+11, i+12, i+13, i+14, i+15]
    let span_id = [i+16, i+17, i+18, i+19, i+20, i+21, i+22, i+23]
    let sc = span_context(trace_id, span_id, i % 2)
    contexts = contexts + [sc]
    i = i + 1
  }
  assert_eq(contexts.length(), 100)
}

test "hex_string_generation_benchmark" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let sc = span_context(trace_id, span_id, 1)
  
  let mut hex_strings = []
  let mut i = 0
  while i < 50 {
    let hex_trace = sc.trace_id_hex()
    let hex_span = sc.span_id_hex()
    hex_strings = hex_strings + [(hex_trace, hex_span)]
    i = i + 1
  }
  assert_eq(hex_strings.length(), 50)
}

test "memory_efficient_context_handling" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 1)
  
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
  
  let hex_trace = sc.trace_id_hex()
  let hex_span = sc.span_id_hex()
  
  assert_eq(hex_trace, "0102030405060708090a0b0c0d0e0f10")
  assert_eq(hex_span, "1112131415161718")
}

test "large_array_handling" {
  let mut large_trace_id = []
  let mut i = 0
  while i < 16 {
    large_trace_id = large_trace_id + [i * 16]
    i = i + 1
  }
  
  let mut large_span_id = []
  let mut j = 0
  while j < 8 {
    large_span_id = large_span_id + [j * 8]
    j = j + 1
  }
  
  let sc = span_context(large_trace_id, large_span_id, 255)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "rapid_context_validation" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  
  let mut valid_count = 0
  let mut invalid_count = 0
  
  let mut flags = 0
  while flags < 256 {
    let sc = span_context(trace_id, span_id, flags)
    if sc.is_valid() {
      valid_count = valid_count + 1
    } else {
      invalid_count = invalid_count + 1
    }
    flags = flags + 1
  }
  
  assert_eq(valid_count, 256)
  assert_eq(invalid_count, 0)
}

test "batch_hex_processing" {
  let mut contexts = []
  let mut trace_start = 1
  let mut i = 0
  while i < 25 {
    let trace_id = [trace_start, trace_start+1, trace_start+2, trace_start+3, trace_start+4, trace_start+5, trace_start+6, trace_start+7, trace_start+8, trace_start+9, trace_start+10, trace_start+11, trace_start+12, trace_start+13, trace_start+14, trace_start+15]
    let span_id = [trace_start+16, trace_start+17, trace_start+18, trace_start+19, trace_start+20, trace_start+21, trace_start+22, trace_start+23]
    let sc = span_context(trace_id, span_id, i % 2)
    contexts = contexts + [sc]
    trace_start = trace_start + 32
    i = i + 1
  }
  
  let mut total_hex_length = 0
  let mut i = 0
  while i < contexts.length() {
    let sc = contexts[i]
    total_hex_length = total_hex_length + sc.trace_id_hex().length() + sc.span_id_hex().length()
    i = i + 1
  }
  
  assert_eq(total_hex_length, 25 * (32 + 16)) // 25 contexts * (32 + 16 hex chars)
}

test "context_creation_edge_cases" {
  // Test with maximum values
  let max_trace = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
  let max_span = [255, 255, 255, 255, 255, 255, 255, 255]
  let sc_max = span_context(max_trace, max_span, 255)
  assert_true(sc_max.is_valid())
  assert_true(sc_max.is_sampled())
  
  // Test with mixed values
  let mixed_trace = [0, 1, 128, 129, 254, 255, 0, 1, 128, 129, 254, 255, 0, 1, 128, 129]
  let mixed_span = [254, 255, 0, 1, 128, 129, 254, 255]
  let sc_mixed = span_context(mixed_trace, mixed_span, 128)
  assert_true(sc_mixed.is_valid())
  assert_false(sc_mixed.is_sampled())
}

test "stress_hex_conversion" {
  let trace_id = [127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142]
  let span_id = [143, 144, 145, 146, 147, 148, 149, 150]
  let sc = span_context(trace_id, span_id, 127)
  
  let mut conversions = 0
  let mut i = 0
  while i < 1000 {
    let hex = sc.trace_id_hex()
    if hex.length() == 32 {
      conversions = conversions + 1
    }
    i = i + 1
  }
  
  assert_eq(conversions, 1000)
}