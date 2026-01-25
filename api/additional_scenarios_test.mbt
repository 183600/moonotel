// Additional scenarios and edge case tests for OpenTelemetry tracing

test "sampler_always_on" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let decision = sampler_always_on(trace_id)
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

test "sampler_always_off" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let decision = sampler_always_off(trace_id)
  assert_false(decision.is_recorded)
  assert_false(decision.is_sampled)
}

test "sampler_trace_id_ratio_0" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let decision = sampler_ratio(trace_id, 0.0)
  assert_false(decision.is_recorded)
  assert_false(decision.is_sampled)
}

test "sampler_trace_id_ratio_1" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let decision = sampler_ratio(trace_id, 1.0)
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

test "sampler_parent_based_valid_parent" {
  let parent_trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let parent_span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let parent_ctx = span_context(parent_trace_id, parent_span_id, 1)
  let decision = sampler_parent_based(parent_ctx, false)
  assert_true(decision.is_recorded)
  assert_true(decision.is_sampled)
}

test "span_context_with_zero_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_with_zero_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  let context = span_context(trace_id, span_id, 1)
  assert_false(context.is_valid())
}

test "span_context_flags_0" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 0)
  assert_false(context.is_sampled())
}

test "span_context_flags_1" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_sampled())
}

test "span_context_flags_3" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 3)
  assert_true(context.is_sampled())
}

test "hex_trace_id_consistency" {
  let trace_id = [0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89]
  let span_id = [0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10]
  let context = span_context(trace_id, span_id, 1)
  let hex = context.trace_id_hex()
  assert_eq(hex, "abcdef0123456789abcdef0123456789")
}

test "hex_span_id_consistency" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89]
  let context = span_context(trace_id, span_id, 1)
  let hex = context.span_id_hex()
  assert_eq(hex, "abcdef0123456789")
}

test "multiple_span_contexts_same_trace" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_ids = [[1, 2, 3, 4, 5, 6, 7, 8], [9, 10, 11, 12, 13, 14, 15, 16], [17, 18, 19, 20, 21, 22, 23, 24]]
  let mut contexts = []
  let mut i = 0
  while i < span_ids.length() {
    let sc = span_context(trace_id, span_ids[i], 1)
    contexts = contexts + [sc]
    i = i + 1
  }
  assert_eq(contexts.length(), 3)
  assert_eq(contexts[0].trace_id_hex(), contexts[1].trace_id_hex())
  assert_eq(contexts[1].trace_id_hex(), contexts[2].trace_id_hex())
  assert_false(contexts[0].span_id_hex() == contexts[1].span_id_hex())
  assert_false(contexts[1].span_id_hex() == contexts[2].span_id_hex())
}

test "span_context_equality_same_values" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context1 = span_context(trace_id, span_id, 1)
  let context2 = span_context(trace_id, span_id, 1)
  assert_eq(context1.trace_id_hex(), context2.trace_id_hex())
  assert_eq(context1.span_id_hex(), context2.span_id_hex())
}

test "span_context_inequality_different_trace" {
  let trace_id1 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let trace_id2 = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context1 = span_context(trace_id1, span_id, 1)
  let context2 = span_context(trace_id2, span_id, 1)
  assert_false(context1.trace_id_hex() == context2.trace_id_hex())
}

test "span_context_inequality_different_span" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id1 = [1, 2, 3, 4, 5, 6, 7, 8]
  let span_id2 = [2, 3, 4, 5, 6, 7, 8, 9]
  let context1 = span_context(trace_id, span_id1, 1)
  let context2 = span_context(trace_id, span_id2, 1)
  assert_false(context1.span_id_hex() == context2.span_id_hex())
}

test "span_context_inequality_different_flags" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context1 = span_context(trace_id, span_id, 1)
  let context2 = span_context(trace_id, span_id, 3)
  assert_true(context1.is_sampled())
  assert_true(context2.is_sampled())
}

test "max_uint64_trace_id" {
  let trace_id = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let span_id = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
  assert_eq(context.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
  assert_eq(context.span_id_hex(), "ffffffffffffffff")
}

test "min_valid_trace_id" {
  let trace_id = [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]
  let span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "max_uint64_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
  assert_eq(context.span_id_hex(), "ffffffffffffffff")
}

test "alternating_bit_trace_id" {
  let trace_id = [0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55]
  let span_id = [0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
  assert_eq(context.trace_id_hex(), "aaaaaaaaaaaaaaaa5555555555555555")
}

test "sequential_span_ids" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let mut contexts = []
  let mut i = 0
  while i < 10 {
    let span_id = [i, i, i, i, i, i, i, i]
    let sc = span_context(trace_id, span_id, 1)
    contexts = contexts + [sc]
    i = i + 1
  }
  assert_eq(contexts.length(), 10)
  let mut i = 0
  while i < contexts.length() - 1 {
    assert_false(contexts[i].span_id_hex() == contexts[i + 1].span_id_hex())
    i = i + 1
  }
}

test "different_sampler_decisions" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let result_always_on = sampler_always_on(trace_id)
  let result_always_off = sampler_always_off(trace_id)
  let result_ratio = sampler_ratio(trace_id, 0.5)
  let parent_ctx = span_context(trace_id, [1, 2, 3, 4, 5, 6, 7, 8], 1)
  let result_parent = sampler_parent_based(parent_ctx, true)
  assert_true(result_always_on.is_sampled)
  assert_false(result_always_off.is_sampled)
  assert_true(result_parent.is_sampled)
}

test "w3c_trace_context_single_byte_span_id" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context = span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "w3c_trace_context_flags_variants" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let context0 = span_context(trace_id, span_id, 0)
  let context1 = span_context(trace_id, span_id, 1)
  let context2 = span_context(trace_id, span_id, 2)
  let context3 = span_context(trace_id, span_id, 3)
  assert_false(context0.is_sampled())
  assert_true(context1.is_sampled())
  assert_false(context2.is_sampled())
  assert_true(context3.is_sampled())
}

test "validation_empty_name" {
  let provider = create_tracer_provider("")
  assert_eq(provider.service_name, "")
}

test "validation_unicode_service_name" {
  let provider = create_tracer_provider("测试服务")
  assert_eq(provider.service_name, "测试服务")
}

test "validation_emoji_service_name" {
  let provider = create_tracer_provider("🔔🔔🔔")
  assert_eq(provider.service_name, "🔔🔔🔔")
}

test "validation_long_service_name" {
  let long_name = "a" + "b" + "c" + "d" + "e" + "f" + "g" + "h" + "i" + "j" +
                  "k" + "l" + "m" + "n" + "o" + "p" + "q" + "r" + "s" + "t" +
                  "u" + "v" + "w" + "x" + "y" + "z" + "0" + "1" + "2" + "3"
  let provider = create_tracer_provider(long_name)
  assert_eq(provider.service_name, long_name)
}

test "span_naming_variants" {
  let provider = create_tracer_provider("test")
  let tracer = create_tracer(provider, "test-tracer")
  
  let operations = [
    "GET /api/users",
    "POST /api/users",
    "PUT /api/users/123",
    "DELETE /api/users/123",
    "GET /health",
    "GET /metrics",
    "database.query",
    "cache.get",
    "cache.set",
    "http.client"
  ]
  
  let mut i = 0
  while i < operations.length() {
    let span = tracer.start_span(operations[i])
    assert_eq(span.name, operations[i])
    i = i + 1
  }
}

test "tracer_name_variants" {
  let provider = create_tracer_provider("test-service")
  
  let tracer_names = [
    "my-tracer",
    "com.example.tracer",
    "tracer-v1",
    "Tracer::Main",
    "worker-1",
    "batch-processor"
  ]
  
  let mut i = 0
  while i < tracer_names.length() {
    let tracer = create_tracer(provider, tracer_names[i])
    assert_eq(tracer.name, tracer_names[i])
    i = i + 1
  }
}

test "span_id_uniqueness_across_tracers" {
  let provider = create_tracer_provider("test")
  let tracer1 = create_tracer(provider, "tracer-1")
  let tracer2 = create_tracer(provider, "tracer-2")
  
  let span1 = tracer1.start_span("op1")
  let span2 = tracer2.start_span("op2")
  
  assert_false(span1.context.span_id_hex() == span2.context.span_id_hex())
}

test "trace_id_stability_same_provider" {
  let provider = create_tracer_provider("test")
  let tracer = create_tracer(provider, "test-tracer")
  
  let span1 = tracer.start_span("op1")
  let span2 = tracer.start_span("op2")
  
  assert_eq(span1.context.trace_id_hex(), span2.context.trace_id_hex())
}

test "span_id_different_across_spans" {
  let provider = create_tracer_provider("test")
  let tracer = create_tracer(provider, "test-tracer")
  
  let mut span_ids = []
  let mut i = 0
  while i < 10 {
    let span = tracer.start_span("op" + i.to_string())
    span_ids = span_ids + [span.context.span_id_hex()]
    i = i + 1
  }
  
  let mut all_unique = true
  let mut i = 0
  while i < span_ids.length() {
    let mut j = i + 1
    while j < span_ids.length() {
      if span_ids[i] == span_ids[j] {
        all_unique = false
      }
      j = j + 1
    }
    i = i + 1
  }
  assert_true(all_unique)
}

test "sampler_consistency" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let mut first_result = false
  let mut i = 0
  while i < 100 {
    let decision = sampler_ratio(trace_id, 1.0)
    if decision.is_sampled {
      first_result = true
    }
    i = i + 1
  }
  assert_true(first_result)
}

test "context_is_valid_variants" {
  let valid_trace_id = [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]
  let invalid_trace_id = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let valid_span_id = [0, 0, 0, 0, 0, 0, 0, 1]
  let invalid_span_id = [0, 0, 0, 0, 0, 0, 0, 0]
  
  let valid_context = span_context(valid_trace_id, valid_span_id, 1)
  let invalid_trace_context = span_context(invalid_trace_id, valid_span_id, 1)
  let invalid_span_context = span_context(valid_trace_id, invalid_span_id, 1)
  let both_invalid_context = span_context(invalid_trace_id, invalid_span_id, 1)
  
  assert_true(valid_context.is_valid())
  assert_false(invalid_trace_context.is_valid())
  assert_false(invalid_span_context.is_valid())
  assert_false(both_invalid_context.is_valid())
}
