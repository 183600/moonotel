///|
fn probe_attr_weight(v : @sdk.AttributeValue) -> Int {
  match v {
    @sdk.StringValue(s) => s.length()
    @sdk.BoolValue(_) => 1
    @sdk.IntValue(n) => n.to_int()
    @sdk.DoubleValue(_) => 8
    @sdk.StringArrayValue(a) => a.length()
    @sdk.BoolArrayValue(a) => a.length()
    @sdk.IntArrayValue(a) => a.length()
    @sdk.DoubleArrayValue(a) => a.length()
  }
}

///|
fn probe_sum_iter(m : Map[String, @sdk.AttributeValue]) -> Int {
  let mut n = 0
  for entry in m.iter() {
    let (k, v) = entry
    n = n + k.length() + probe_attr_weight(v)
  }
  n
}

///|
fn probe_sum_each(m : Map[String, @sdk.AttributeValue]) -> Int {
  let mut n = 0
  m.each(fn(k, v) { n = n + k.length() + probe_attr_weight(v) })
  n
}

///|
test "zz_perf_probe_map_iter" (b : @bench.T) {
  let attrs : Map[String, @sdk.AttributeValue] = Map([
    ("http.request.method", StringValue("GET")),
    ("url.full", StringValue("http://example.com/path?q=1")),
    ("server.address", StringValue("example.com")),
    ("server.port", IntValue(80L)),
    ("http.response.status_code", IntValue(200L)),
  ])
  b.bench(fn() {
    let _ = probe_sum_iter(attrs)
  })
  b.bench(fn() {
    let _ = probe_sum_each(attrs)
  })
}
