// QuickCheck-style property tests for span_context invariants
// 
// While MoonBit doesn't ship QuickCheck, we manually test representative sets

test "property_trace_id_hex_length_always_32_for_valid_length" {
  // For any 16-byte array, hex is 32 characters
  let pattern = Array::make(16, 0)
  let mut i = 0
  while i < 16 {
    pattern[i] = i
    let hex = bytes_to_hex(pattern)
    assert_eq(hex.length(), 32)
    i = i + 1
  }
}

test "property_span_id_hex_length_always_16_for_valid_length" {
  // For any 8-byte array, hex is 16 characters
  let pattern = Array::make(8, 0)
  let mut i = 0
  while i < 8 {
    pattern[i] = i
    let hex = bytes_to_hex(pattern)
    assert_eq(hex.length(), 16)
    i = i + 1
  }
}

test "property_valid_span_context_requires_nonzero_ids" {
  let valid_tid = Array::make(16, 1)
  let valid_sid = Array::make(8, 1)
  let zero_tid = Array::make(16, 0)
  let zero_sid = Array::make(8, 0)

  let sc_ok = span_context(valid_tid, valid_sid, 0)
  assert_true(sc_ok.is_valid())

  let sc_zero_tid = span_context(zero_tid, valid_sid, 0)
  assert_false(sc_zero_tid.is_valid())

  let sc_zero_sid = span_context(valid_tid, zero_sid, 0)
  assert_false(sc_zero_sid.is_valid())

  let sc_both_zero = span_context(zero_tid, zero_sid, 0)
  assert_false(sc_both_zero.is_valid())
}

test "property_sampled_flag_only_depends_on_bit_0" {
  let trace_id = Array::make(16, 1)
  let span_id = Array::make(8, 1)

  let mut flags = 0
  while flags < 256 {
    let sc = span_context(trace_id, span_id, flags)
    let expected_sampled = (flags & 1) != 0
    assert_eq(sc.is_sampled(), expected_sampled)
    flags = flags + 1
  }
}

test "property_is_zero_iff_all_elements_zero" {
  // all zeros => is_zero
  assert_true(is_zero(Array::make(0, 0)))
  assert_true(is_zero(Array::make(1, 0)))
  assert_true(is_zero(Array::make(10, 0)))
  assert_true(is_zero(Array::make(16, 0)))

  // any non-zero => not is_zero
  let arr = Array::make(16, 0)
  assert_true(is_zero(arr))
  arr[0] = 1
  assert_false(is_zero(arr))

  let arr2 = Array::make(16, 0)
  arr2[15] = 1
  assert_false(is_zero(arr2))
}

fn is_lower_hex_char(c : Char) -> Bool {
  c == '0' || c == '1' || c == '2' || c == '3' || c == '4' || c == '5' || c == '6' || c == '7' || c == '8' || c == '9' ||
  c == 'a' || c == 'b' || c == 'c' || c == 'd' || c == 'e' || c == 'f'
}

test "property_bytes_to_hex_only_uses_lower_hex_chars" {
  let mut b = 0
  while b < 256 {
    let hex = bytes_to_hex([b])
    let chars = hex.to_array()
    assert_eq(chars.length(), 2)
    assert_true(is_lower_hex_char(chars[0]))
    assert_true(is_lower_hex_char(chars[1]))
    b = b + 1
  }
}

test "property_bytes_to_hex_length_twice_input" {
  let mut len = 0
  while len <= 20 {
    let arr = Array::make(len, 0)
    let hex = bytes_to_hex(arr)
    assert_eq(hex.length(), len * 2)
    len = len + 1
  }
}



