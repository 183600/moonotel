// Probe: cost of the two clock wrappers used by the SDK (results are
// loop-carried so the calls cannot be optimized away).

///|
test "zz_myprobe_ffi_wb" (b : @bench.T) {
  let mut acc = 0
  b.bench(fn() {
    acc = acc + @env.now().to_int()
  })
  b.bench(fn() {
    acc = acc + unix_nano_now().to_int()
  })
  b.keep(acc)
}
