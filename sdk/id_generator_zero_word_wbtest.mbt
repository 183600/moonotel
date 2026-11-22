// A splitmix64 word can legitimately be zero. Trace and span IDs must never be
// all zero, so the generator forces the last byte to one when an entire draw
// happens to be zero.

///|
test "pseudo_random_bytes normalizes an all-zero word" {
  // This seed is splitmix64's first state minus its gamma constant, so the
  // first generated word is zero.
  let state = Ref(7046029254386353131UL)
  let out = pseudo_random_bytes(8, state)
  assert_eq(out.length(), 8)
  for i = 0; i < 7; i = i + 1 {
    assert_eq(out[i], 0)
  }
  assert_eq(out[7], 1)
}

///|
test "deterministic generator never emits an all-zero span id" {
  let generator = IdGenerator::deterministic(7046029254386353131UL)
  let span_id = generator.generate_span_id()
  assert_eq(span_id.length(), 8)
  for i = 0; i < 7; i = i + 1 {
    assert_eq(span_id[i], 0)
  }
  assert_eq(span_id[7], 1)
}
