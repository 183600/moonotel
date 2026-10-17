///|
test "zz_bench_api" (b : @bench.T) {
  let trace_hex = "0102030405060708090a0b0c0d0e0f10"
  let span_hex = "1112131415161718"
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [17, 18, 19, 20, 21, 22, 23, 24]
  let sc = span_context(trace_id, span_id, 1)
  b.bench(fn() {
    let _ = span_context(trace_id, span_id, 1)
  })
  b.bench(fn() {
    let _ = sc.trace_id_hex()
    let _ = sc.span_id_hex()
  })
  b.bench(fn() {
    let _ = bytes_from_hex(trace_hex)
    let _ = bytes_from_hex(span_hex)
  })
  b.bench(fn() {
    let _ = span_context_from_hex(trace_hex, span_hex, 1)
  })
}
