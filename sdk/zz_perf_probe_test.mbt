///|
test "zz_perf_probe_sdk" (b : @bench.T) {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  b.bench(fn() {
    let _ = @env.now()
  })
  b.bench(fn() {
    let _ : Array[Int32] = []
    let _ = 0
  })
  b.bench(fn() {
    let _ = @api.span_context(trace_id, span_id, 1)
  })
  let gen = IdGenerator::random()
  b.bench(fn() {
    let _ = gen.generate_trace_id()
  })
  b.bench(fn() {
    let _ = gen.generate_span_id()
  })
  let sampler = Sampler::parent_based(Sampler::always_on())
  b.bench(fn() {
    let _ = sampler.should_sample(None, trace_id)
  })
}
