// Zero-length ID requests must not normalize an out-of-range last element.

///|
test "pseudo_random_bytes zero length is empty" {
  let state = Ref(123UL)
  let out = pseudo_random_bytes(0, state)
  assert_eq(out.length(), 0)
}

///|
test "pseudo_random_bytes negative length is empty" {
  let state = Ref(123UL)
  let out = pseudo_random_bytes(-1, state)
  assert_eq(out.length(), 0)
}

///|
test "take_buffered zero length does not consume the buffer" {
  let pending = Ref(b"\x01\x02\x03")
  let offset = Ref(0)
  match take_buffered(0, pending, offset) {
    Some(out) => assert_eq(out.length(), 0)
    None => abort("expected an empty result")
  }
  assert_eq(offset.val, 0)
  assert_eq(pending.val.length(), 3)
}

///|
test "take_buffered negative length is empty" {
  let pending = Ref(b"\x01\x02\x03")
  let offset = Ref(0)
  match take_buffered(-1, pending, offset) {
    Some(out) => assert_eq(out.length(), 0)
    None => abort("expected an empty result")
  }
  assert_eq(offset.val, 0)
  assert_eq(pending.val.length(), 3)
}
