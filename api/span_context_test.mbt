// Internal tests for SpanContext

// Helper to create zero-filled array of given length
fn zeros(n : Int) -> Array[Int] {
  Array::make(n, 0)
}

test "invalid_span_context" {
  let sc = invalid_span_context()
  assert_false(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "invalid_span_context_trace_id_zero" {
  let sc = invalid_span_context()
  let tid = sc.trace_id
  assert_eq(tid.length(), 16)
  let mut i = 0
  while i < 16 {
    assert_eq(tid[i], 0)
    i = i + 1
  }
}

test "invalid_span_context_span_id_zero" {
  let sc = invalid_span_context()
  let sid = sc.span_id
  assert_eq(sid.length(), 8)
  let mut i = 0
  while i < 8 {
    assert_eq(sid[i], 0)
    i = i + 1
  }
}

test "invalid_span_context_flags_zero" {
  let sc = invalid_span_context()
  assert_eq(sc.trace_flags, 0)
}

test "valid_span_context" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let flags = 1
  
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "not_sampled_span_context" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let flags = 0
  
  let sc = span_context(trace_id, span_id, flags)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "zero_trace_id_invalid" {
  let trace_id = zeros(16)
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  let flags = 1
  
  let sc = span_context(trace_id, span_id, flags)
  assert_false(sc.is_valid())
}

test "zero_span_id_invalid" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = zeros(8)
  let flags = 1
  
  let sc = span_context(trace_id, span_id, flags)
  assert_false(sc.is_valid())
}

test "trace_id_hex" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  
  let sc = span_context(trace_id, span_id, 1)
  let hex = sc.trace_id_hex()
  
  // Expected: "000102030405060708090a0b0c0d0e0f"
  assert_eq(hex.length(), 32)
}

test "span_id_hex" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  
  let sc = span_context(trace_id, span_id, 1)
  let hex = sc.span_id_hex()
  
  // Expected: "1011121314151617"
  assert_eq(hex.length(), 16)
}

test "sampled_flag" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [16, 17, 18, 19, 20, 21, 22, 23]
  
  // Test with sampled bit set
  let sc1 = span_context(trace_id, span_id, 1)
  assert_true(sc1.is_sampled())
  
  // Test with sampled bit not set
  let sc2 = span_context(trace_id, span_id, 0)
  assert_false(sc2.is_sampled())
  
  // Test with multiple bits set
  let sc3 = span_context(trace_id, span_id, 255)
  assert_true(sc3.is_sampled())
}
