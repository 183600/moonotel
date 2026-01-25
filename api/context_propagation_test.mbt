// Tests for context propagation and parent-child relationships

test "parent_child_same_trace_id" {
  let parent_trace_id = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
  let parent_span_id = [11, 22, 33, 44, 55, 66, 77, 88]
  let parent_ctx = span_context(parent_trace_id, parent_span_id, 1)
  
  let child_span_id = [99, 88, 77, 66, 55, 44, 33, 22]
  let child_ctx = span_context(parent_trace_id, child_span_id, 1)
  
  assert_eq(parent_ctx.trace_id_hex(), child_ctx.trace_id_hex())
  assert_true(parent_ctx.span_id_hex() != child_ctx.span_id_hex())
}

test "sibling_spans_different_span_ids" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  
  let sibling1_span_id = [10, 20, 30, 40, 50, 60, 70, 80]
  let sibling2_span_id = [11, 21, 31, 41, 51, 61, 71, 81]
  let sibling3_span_id = [12, 22, 32, 42, 52, 62, 72, 82]
  
  let ctx1 = span_context(trace_id, sibling1_span_id, 1)
  let ctx2 = span_context(trace_id, sibling2_span_id, 1)
  let ctx3 = span_context(trace_id, sibling3_span_id, 1)
  
  assert_eq(ctx1.trace_id_hex(), ctx2.trace_id_hex())
  assert_eq(ctx2.trace_id_hex(), ctx3.trace_id_hex())
  
  assert_true(ctx1.span_id_hex() != ctx2.span_id_hex())
  assert_true(ctx2.span_id_hex() != ctx3.span_id_hex())
  assert_true(ctx1.span_id_hex() != ctx3.span_id_hex())
}

test "sampling_propagation_sampled_parent" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let parent_span_id = [10, 20, 30, 40, 50, 60, 70, 80]
  let parent_ctx = span_context(trace_id, parent_span_id, 1)
  
  let child_span_id = [11, 21, 31, 41, 51, 61, 71, 81]
  let child_ctx = span_context(trace_id, child_span_id, 1)
  
  assert_true(parent_ctx.is_sampled())
  assert_true(child_ctx.is_sampled())
}

test "sampling_propagation_unsampled_parent" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let parent_span_id = [10, 20, 30, 40, 50, 60, 70, 80]
  let parent_ctx = span_context(trace_id, parent_span_id, 0)
  
  let child_span_id = [11, 21, 31, 41, 51, 61, 71, 81]
  let child_ctx = span_context(trace_id, child_span_id, 0)
  
  assert_false(parent_ctx.is_sampled())
  assert_false(child_ctx.is_sampled())
}

test "deep_nesting_trace_id_consistency" {
  let trace_id = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]
  
  let span_ids = [
    [1, 0, 0, 0, 0, 0, 0, 0],
    [2, 0, 0, 0, 0, 0, 0, 0],
    [3, 0, 0, 0, 0, 0, 0, 0],
    [4, 0, 0, 0, 0, 0, 0, 0],
    [5, 0, 0, 0, 0, 0, 0, 0]
  ]
  
  let mut contexts = []
  let mut i = 0
  while i < span_ids.length() {
    let ctx = span_context(trace_id, span_ids[i], 1)
    contexts = contexts + [ctx]
    i = i + 1
  }
  
  let base_trace_id_hex = contexts[0].trace_id_hex()
  let mut all_match = true
  let mut j = 1
  while j < contexts.length() {
    if contexts[j].trace_id_hex() != base_trace_id_hex {
      all_match = false
    }
    j = j + 1
  }
  
  assert_true(all_match)
}

test "context_validity_propagation" {
  let valid_trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let valid_span_id = [10, 20, 30, 40, 50, 60, 70, 80]
  
  let parent_ctx = span_context(valid_trace_id, valid_span_id, 1)
  assert_true(parent_ctx.is_valid())
  
  let child_span_id = [11, 21, 31, 41, 51, 61, 71, 81]
  let child_ctx = span_context(valid_trace_id, child_span_id, 1)
  assert_true(child_ctx.is_valid())
}

test "invalid_parent_invalid_propagation" {
  let invalid_ctx = invalid_span_context()
  assert_false(invalid_ctx.is_valid())
}

test "mixed_sampling_across_spans" {
  let trace_id = [50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65]
  
  let span1_id = [10, 20, 30, 40, 50, 60, 70, 80]
  let span2_id = [11, 21, 31, 41, 51, 61, 71, 81]
  let span3_id = [12, 22, 32, 42, 52, 62, 72, 82]
  
  let ctx1 = span_context(trace_id, span1_id, 1)
  let ctx2 = span_context(trace_id, span2_id, 0)
  let ctx3 = span_context(trace_id, span3_id, 1)
  
  assert_true(ctx1.is_sampled())
  assert_false(ctx2.is_sampled())
  assert_true(ctx3.is_sampled())
  
  assert_eq(ctx1.trace_id_hex(), ctx2.trace_id_hex())
  assert_eq(ctx2.trace_id_hex(), ctx3.trace_id_hex())
}

test "trace_id_preservation_across_boundaries" {
  let trace_id = [200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215]
  let trace_id_hex_expected = bytes_to_hex(trace_id)
  
  let span_id1 = [1, 1, 1, 1, 1, 1, 1, 1]
  let ctx1 = span_context(trace_id, span_id1, 1)
  assert_eq(ctx1.trace_id_hex(), trace_id_hex_expected)
  
  let span_id2 = [2, 2, 2, 2, 2, 2, 2, 2]
  let ctx2 = span_context(trace_id, span_id2, 0)
  assert_eq(ctx2.trace_id_hex(), trace_id_hex_expected)
  
  let span_id3 = [3, 3, 3, 3, 3, 3, 3, 3]
  let ctx3 = span_context(trace_id, span_id3, 255)
  assert_eq(ctx3.trace_id_hex(), trace_id_hex_expected)
}

test "span_id_uniqueness_within_trace" {
  let trace_id = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]
  
  let mut span_id_hexes = []
  let mut i = 0
  while i < 20 {
    let span_id = [i, i+1, i+2, i+3, i+4, i+5, i+6, i+7]
    let ctx = span_context(trace_id, span_id, 1)
    span_id_hexes = span_id_hexes + [ctx.span_id_hex()]
    i = i + 1
  }
  
  let mut all_unique = true
  let mut j = 0
  while j < span_id_hexes.length() {
    let mut k = j + 1
    while k < span_id_hexes.length() {
      if span_id_hexes[j] == span_id_hexes[k] {
        all_unique = false
      }
      k = k + 1
    }
    j = j + 1
  }
  
  assert_true(all_unique)
}

test "context_equality_same_ids" {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [10, 20, 30, 40, 50, 60, 70, 80]
  
  let ctx1 = span_context(trace_id, span_id, 1)
  let ctx2 = span_context(trace_id, span_id, 1)
  
  assert_eq(ctx1.trace_id_hex(), ctx2.trace_id_hex())
  assert_eq(ctx1.span_id_hex(), ctx2.span_id_hex())
  assert_eq(ctx1.is_sampled(), ctx2.is_sampled())
}

test "context_inequality_different_trace_ids" {
  let trace_id1 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let trace_id2 = [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  let span_id = [10, 20, 30, 40, 50, 60, 70, 80]
  
  let ctx1 = span_context(trace_id1, span_id, 1)
  let ctx2 = span_context(trace_id2, span_id, 1)
  
  assert_true(ctx1.trace_id_hex() != ctx2.trace_id_hex())
}

test "fan_out_pattern_single_parent_multiple_children" {
  let parent_trace_id = [99, 98, 97, 96, 95, 94, 93, 92, 91, 90, 89, 88, 87, 86, 85, 84]
  let parent_span_id = [50, 51, 52, 53, 54, 55, 56, 57]
  
  let child_count = 5
  let mut children = []
  let mut i = 0
  while i < child_count {
    let child_span_id = [100+i, 101+i, 102+i, 103+i, 104+i, 105+i, 106+i, 107+i]
    let child_ctx = span_context(parent_trace_id, child_span_id, 1)
    children = children + [child_ctx]
    i = i + 1
  }
  
  let parent_trace_hex = bytes_to_hex(parent_trace_id)
  let mut all_children_match_parent = true
  let mut j = 0
  while j < children.length() {
    if children[j].trace_id_hex() != parent_trace_hex {
      all_children_match_parent = false
    }
    j = j + 1
  }
  
  assert_true(all_children_match_parent)
}

test "sequential_span_creation_pattern" {
  let trace_id = [111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126]
  
  let operations = ["init", "process", "validate", "store", "finalize"]
  let mut sequence = []
  
  let mut i = 0
  while i < operations.length() {
    let span_id = [i*10, i*10+1, i*10+2, i*10+3, i*10+4, i*10+5, i*10+6, i*10+7]
    let ctx = span_context(trace_id, span_id, 1)
    sequence = sequence + [(operations[i], ctx)]
    i = i + 1
  }
  
  assert_eq(sequence.length(), 5)
  
  let base_trace_hex = sequence[0].1.trace_id_hex()
  let mut all_same_trace = true
  let mut k = 1
  while k < sequence.length() {
    if sequence[k].1.trace_id_hex() != base_trace_hex {
      all_same_trace = false
    }
    k = k + 1
  }
  
  assert_true(all_same_trace)
}
