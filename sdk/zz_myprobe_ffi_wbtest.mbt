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
