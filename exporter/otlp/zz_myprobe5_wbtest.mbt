///|
test "zz_myprobe_map_wb" (b : @bench.T) {
  let attrs : Map[String, @sdk.AttributeValue] = Map([
    ("http.request.method", StringValue("GET")),
    ("url.full", StringValue("http://example.com/path?q=1")),
    ("server.address", StringValue("example.com")),
    ("server.port", IntValue(80L)),
    ("http.response.status_code", IntValue(200L)),
  ])
  let acc = Ref(0)
  b.bench(fn() {
    attrs.each(fn(k, _v) { acc.val = acc.val + k.length() })
  })
  b.bench(fn() {
    for k, _v in attrs {
      acc.val = acc.val + k.length()
    }
  })
  b.bench(fn() {
    for entry in attrs.iter() {
      acc.val = acc.val + entry.0.length()
    }
  })
  b.keep(acc.val)
}
