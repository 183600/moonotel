///|
test "zz_bench_propagation" (b : @bench.T) {
  let traceparent = "00-0102030405060708090a0b0c0d0e0f10-1112131415161718-01"
  let tracestate = "vendor1=value1,vendor2=value2,vendor3=value3"
  let baggage = "key1=value1;prop=1,key2=value2,key3=value3"
  let sc = parse_traceparent(traceparent).unwrap()
  b.bench(fn() {
    let _ = parse_traceparent(traceparent)
  })
  b.bench(fn() {
    let _ = format_traceparent(sc)
  })
  b.bench(fn() {
    let _ = parse_tracestate(tracestate)
  })
  b.bench(fn() {
    let _ = parse_baggage(baggage)
  })
  b.bench(fn() {
    let carrier = TextMapCarrier::new()
    inject(sc, carrier)
    let _ = extract(carrier)
  })
  b.bench(fn() {
    let carrier = TextMapCarrier::new()
    carrier.set("traceparent", traceparent)
    carrier.set("tracestate", tracestate)
    carrier.set("baggage", baggage)
    let _ = carrier.get("traceparent")
    let _ = carrier.get("TRACEPARENT")
  })
  b.bench(fn() {
    let context = @context.Context::root().with_value("k1", "v1").with_value("k2", "v2")
    let _ = context_baggage_header(context)
  })
}
