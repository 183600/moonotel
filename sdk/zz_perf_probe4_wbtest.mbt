
///|
fn probe_take_old(
  n : Int,
  pending : Ref[Bytes],
  offset : Ref[Int]
) -> Array[Int]? {
  let source = pending.val
  let start = offset.val
  if source.length() - start < n {
    return None
  }
  let out : Array[Int] = Array::unsafe_make_uninit(n)
  let mut acc = 0
  let mut i = 0
  while i < n {
    let b = source.unsafe_get(start + i).to_int()
    out.unsafe_set(i, b)
    acc = acc | b
    i = i + 1
  }
  if acc == 0 {
    out.unsafe_set(n - 1, 1)
  }
  if start + n >= source.length() {
    pending.val = b""
    offset.val = 0
  } else {
    offset.val = start + n
  }
  Some(out)
}

///|
test "zz_probe_take_ab" (b : @bench.T) {
  let source = @env.rand(RANDOM_DRAW_BYTES).unwrap()
  let pending : Ref[Bytes] = Ref(source)
  let offset : Ref[Int] = Ref(0)
  let pending2 : Ref[Bytes] = Ref(source)
  let offset2 : Ref[Int] = Ref(0)
  b.bench(fn() {
    pending2.val = source
    offset2.val = 0
    let _ = probe_take_old(16, pending2, offset2)
  })
  b.bench(fn() {
    pending.val = source
    offset.val = 0
    let _ = take_buffered(16, pending, offset)
  })
  b.bench(fn() {
    pending2.val = source
    offset2.val = 0
    let _ = probe_take_old(8, pending2, offset2)
  })
  b.bench(fn() {
    pending.val = source
    offset.val = 0
    let _ = take_buffered(8, pending, offset)
  })
}

///|
fn probe_random_old(
  n : Int,
  state : Ref[UInt64],
  pending : Ref[Bytes],
  offset : Ref[Int]
) -> Array[Int] {
  match probe_take_old(n, pending, offset) {
    Some(bytes) => bytes
    None => {
      let draw = if n < RANDOM_DRAW_BYTES { RANDOM_DRAW_BYTES } else { n }
      match @env.rand(draw) {
        Some(bytes) => {
          pending.val = bytes
          offset.val = 0
          match probe_take_old(n, pending, offset) {
            Some(out) => out
            None => pseudo_random_bytes(n, state)
          }
        }
        None => pseudo_random_bytes(n, state)
      }
    }
  }
}

///|
test "zz_probe_gen_ab" (b : @bench.T) {
  let state = Ref(1UL)
  let pending : Ref[Bytes] = Ref(b"")
  let offset : Ref[Int] = Ref(0)
  let state2 = Ref(1UL)
  let pending2 : Ref[Bytes] = Ref(b"")
  let offset2 : Ref[Int] = Ref(0)
  b.bench(fn() {
    let _ = random_bytes(16, state, pending, offset)
    let _ = random_bytes(8, state, pending, offset)
  })
  b.bench(fn() {
    let _ = probe_random_old(16, state2, pending2, offset2)
    let _ = probe_random_old(8, state2, pending2, offset2)
  })
  b.bench(fn() {
    let _ = probe_random_old(16, state2, pending2, offset2)
    let _ = probe_random_old(8, state2, pending2, offset2)
  })
  b.bench(fn() {
    let _ = random_bytes(16, state, pending, offset)
    let _ = random_bytes(8, state, pending, offset)
  })
}
