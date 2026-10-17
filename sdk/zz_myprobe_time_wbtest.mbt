///|
test "zz_myprobe_time_wb" (b : @bench.T) {
  b.bench(fn() {
    let _ = @env.now()
  })
  b.bench(fn() {
    let _ = unix_nano_now()
  })
}
