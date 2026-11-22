// The ID generators must handle byte counts that are not a multiple of eight
// and buffers that are consumed exactly, without leaving uninitialized bytes or
// reusing consumed entropy.

///|
test "pseudo_random_bytes fills a partial trailing word" {
  let state = Ref(42UL)
  let first = splitmix64(state)
  let second = splitmix64(state)
  let out = pseudo_random_bytes(9, Ref(42UL))
  assert_eq(out.length(), 9)
  for i = 0; i < 8; i = i + 1 {
    assert_eq(out[i].to_int(), ((first >> (i * 8)) & 0xFF).to_int())
  }
  assert_eq(out[8].to_int(), (second & 0xFF).to_int())
}

///|
test "take_buffered consumes a partial trailing word" {
  let pending = Ref(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09")
  let offset = Ref(0)
  match take_buffered(9, pending, offset) {
    Some(out) => {
      assert_eq(out.length(), 9)
      for i = 0; i < 9; i = i + 1 {
        assert_eq(out[i].to_int(), i + 1)
      }
    }
    None => abort("expected a buffered draw")
  }
  // The whole draw was consumed, so it is released instead of leaving a
  // zero-length buffer with a nonzero offset.
  assert_eq(offset.val, 0)
  assert_eq(pending.val.length(), 0)
}

///|
test "take_buffered leaves the unconsumed tail of a larger draw" {
  let pending = Ref(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A")
  let offset = Ref(0)
  match take_buffered(9, pending, offset) {
    Some(out) => {
      assert_eq(out.length(), 9)
      for i = 0; i < 9; i = i + 1 {
        assert_eq(out[i].to_int(), i + 1)
      }
    }
    None => abort("expected a buffered draw")
  }
  assert_eq(offset.val, 9)
  assert_eq(pending.val.length(), 10)
}

///|
test "take_buffered normalizes an all-zero draw to a non-zero id" {
  let pending = Ref(b"\x00\x00\x00\x00\x00\x00\x00\x00\x00")
  let offset = Ref(0)
  match take_buffered(9, pending, offset) {
    Some(out) => {
      assert_eq(out.length(), 9)
      for i = 0; i < 8; i = i + 1 {
        assert_eq(out[i].to_int(), 0)
      }
      // All-zero IDs are invalid, so the last byte is forced to one.
      assert_eq(out[8].to_int(), 1)
    }
    None => abort("expected a buffered draw")
  }
}
