///|
test "zz_myprobe_rand_wb" (b : @bench.T) {
  b.bench(fn() {
    let _ = @env.rand(1920)
  })
  b.bench(fn() {
    let _ = @env.rand(8192)
  })
  b.bench(fn() {
    let _ = @env.rand(16384)
  })
  b.bench(fn() {
    let _ = @env.rand(64)
  })
  let state = Ref(1UL)
  let pending : Ref[Bytes] = Ref(b"")
  let offset : Ref[Int] = Ref(0)
  b.bench(fn() {
    let _ = random_bytes(16, state, pending, offset)
  })
  b.bench(fn() {
    let _ = random_bytes(8, state, pending, offset)
  })
}
