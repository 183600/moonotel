// Boundary condition tests for SpanContext

test "trace_id_all_boundary_bytes" {
  let tid = [0, 1, 127, 128, 254, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
  let hex = sc.trace_id_hex()
  assert_eq(hex.length(), 32)
}

test "span_id_all_boundary_bytes" {
  let tid = Array::make(16, 1)
  let sid = [0, 1, 127, 128, 254, 255, 0, 1]
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
  let hex = sc.span_id_hex()
  assert_eq(hex.length(), 16)
}

test "trace_flags_all_byte_values" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  let mut flags = 0
  while flags < 256 {
    let sc = span_context(tid, sid, flags)
    assert_true(sc.is_valid())
    assert_eq(sc.trace_flags, flags)
    flags = flags + 1
  }
}

test "hex_for_sequential_bytes" {
  let sequential = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let hex = bytes_to_hex(sequential)
  assert_eq(hex, "000102030405060708090a0b0c0d0e0f")
}

test "hex_for_reverse_sequential_bytes" {
  let reverse = [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  let hex = bytes_to_hex(reverse)
  assert_eq(hex, "0f0e0d0c0b0a09080706050403020100")
}

test "minimum_valid_span_context" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "maximum_valid_span_context" {
  let tid = Array::make(16, 255)
  let sid = Array::make(8, 255)
  let sc = span_context(tid, sid, 255)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "single_nonzero_byte_in_trace_id" {
  let tid = Array::make(16, 0)
  tid[0] = 1
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
}

test "single_nonzero_byte_in_span_id" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 0)
  sid[0] = 1
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
}

test "last_byte_nonzero_in_trace_id" {
  let tid = Array::make(16, 0)
  tid[15] = 1
  let sid = Array::make(8, 1)
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
}

test "last_byte_nonzero_in_span_id" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 0)
  sid[7] = 1
  let sc = span_context(tid, sid, 0)
  assert_true(sc.is_valid())
}

test "bytes_to_hex_power_of_two_bytes" {
  assert_eq(bytes_to_hex([1]), "01")
  assert_eq(bytes_to_hex([2]), "02")
  assert_eq(bytes_to_hex([4]), "04")
  assert_eq(bytes_to_hex([8]), "08")
  assert_eq(bytes_to_hex([16]), "10")
  assert_eq(bytes_to_hex([32]), "20")
  assert_eq(bytes_to_hex([64]), "40")
  assert_eq(bytes_to_hex([128]), "80")
}

test "is_zero_large_arrays" {
  assert_true(is_zero(Array::make(1000, 0)))
  assert_true(is_zero(Array::make(10000, 0)))
}

test "is_zero_single_nonzero_in_large_array" {
  let large = Array::make(1000, 0)
  large[500] = 1
  assert_false(is_zero(large))
}

test "trace_flags_odd_even_pattern" {
  let tid = Array::make(16, 1)
  let sid = Array::make(8, 1)
  
  // Even flags (bit 0 = 0) should not be sampled
  assert_false(span_context(tid, sid, 0).is_sampled())
  assert_false(span_context(tid, sid, 2).is_sampled())
  assert_false(span_context(tid, sid, 4).is_sampled())
  assert_false(span_context(tid, sid, 254).is_sampled())
  
  // Odd flags (bit 0 = 1) should be sampled
  assert_true(span_context(tid, sid, 1).is_sampled())
  assert_true(span_context(tid, sid, 3).is_sampled())
  assert_true(span_context(tid, sid, 5).is_sampled())
  assert_true(span_context(tid, sid, 255).is_sampled())
}



