///|
fn probe_bytes_copy(n : Int, source : Bytes, start : Int) -> Array[Int] {
  let out : Array[Int] = Array::unsafe_make_uninit(n)
  let mut i = 0
  while i < n {
    out.unsafe_set(i, source.unsafe_get(start + i).to_int())
    i = i + 1
  }
  out
}

///|
fn probe_bytes_copy4(n : Int, source : Bytes, start : Int) -> Array[Int] {
  let out : Array[Int] = Array::unsafe_make_uninit(n)
  let mut i = 0
  while i + 4 <= n {
    let word = source.unsafe_read_uint32_le(start + i)
    out.unsafe_set(i, (word & 0xFF).to_int())
    out.unsafe_set(i + 1, ((word >> 8) & 0xFF).to_int())
    out.unsafe_set(i + 2, ((word >> 16) & 0xFF).to_int())
    out.unsafe_set(i + 3, (word >> 24).to_int())
    i = i + 4
  }
  while i < n {
    out.unsafe_set(i, source.unsafe_get(start + i).to_int())
    i = i + 1
  }
  out
}

///|
fn probe_bytes_copy8(n : Int, source : Bytes, start : Int) -> Array[Int] {
  let out : Array[Int] = Array::unsafe_make_uninit(n)
  let mut i = 0
  while i + 8 <= n {
    let word = source.unsafe_read_uint64_le(start + i)
    out.unsafe_set(i, (word & 0xFF).to_int())
    out.unsafe_set(i + 1, ((word >> 8) & 0xFF).to_int())
    out.unsafe_set(i + 2, ((word >> 16) & 0xFF).to_int())
    out.unsafe_set(i + 3, ((word >> 24) & 0xFF).to_int())
    out.unsafe_set(i + 4, ((word >> 32) & 0xFF).to_int())
    out.unsafe_set(i + 5, ((word >> 40) & 0xFF).to_int())
    out.unsafe_set(i + 6, ((word >> 48) & 0xFF).to_int())
    out.unsafe_set(i + 7, (word >> 56).to_int())
    i = i + 8
  }
  while i < n {
    out.unsafe_set(i, source.unsafe_get(start + i).to_int())
    i = i + 1
  }
  out
}

///|
test "zz_perf_probe_bytes" (b : @bench.T) {
  let source : Bytes = Bytes::make(1920, b'\x01')
  b.bench(fn() {
    let _ = probe_bytes_copy(16, source, 0)
  })
  b.bench(fn() {
    let _ = probe_bytes_copy(8, source, 0)
  })
  b.bench(fn() {
    let _ = probe_bytes_copy4(16, source, 0)
  })
  b.bench(fn() {
    let _ = probe_bytes_copy4(8, source, 0)
  })
  b.bench(fn() {
    let _ = probe_bytes_copy8(16, source, 0)
  })
  b.bench(fn() {
    let _ = probe_bytes_copy8(8, source, 0)
  })
}

