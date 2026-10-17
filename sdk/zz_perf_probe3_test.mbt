///|
fn probe_frac(trace_id : Array[Int]) -> UInt64 {
  let mut value : UInt64 = 0
  let mut i = 0
  while i < 8 {
    value = (value << 8) | (trace_id.unsafe_get(i).to_uint64() & 0xFF)
    i = i + 1
  }
  value
}

///|
test "zz_perf_probe_sampler" (b : @bench.T) {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  b.bench(fn() {
    let _ = probe_frac(trace_id)
  })
  b.bench(fn() {
    let _ = probe_frac(trace_id) >> 1
    let _ = 0
  })
  let sampler = Sampler::trace_id_ratio_based(0.5)
  b.bench(fn() {
    let _ = sampler.should_sample(None, trace_id)
  })
  let parent_sampler = Sampler::parent_based(Sampler::always_on())
  b.bench(fn() {
    let _ = parent_sampler.should_sample(None, trace_id)
  })
  b.bench(fn() {
    let _ = sampler.should_sample(Some(@api.span_context(trace_id[:16].to_owned(), trace_id[:8].to_owned(), 1)), trace_id)
  })
}
