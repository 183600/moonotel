///|
test "zz_myprobe_provider_wb" (b : @bench.T) {
  b.bench(fn() {
    let _ = @env.get_env_var("OTEL_TRACES_SAMPLER")
  })
  b.bench(fn() {
    let _ = TracerProviderSdk::new()
  })
  b.bench(fn() {
    let _ = SpanLimits::from_env()
  })
  b.bench(fn() {
    let _ = Sampler::from_env()
  })
}
