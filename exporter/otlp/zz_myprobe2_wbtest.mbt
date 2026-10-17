///|
test "zz_myprobe_encode_wb2" (b : @bench.T) {
  let attributes : Map[String, @sdk.AttributeValue] = Map([
    ("http.request.method", StringValue("GET")),
    ("url.full", StringValue("http://example.com/path?q=1")),
    ("server.address", StringValue("example.com")),
    ("server.port", IntValue(80L)),
    ("http.response.status_code", IntValue(200L)),
  ])
  let events : Array[@sdk.SpanEvent] = [
    { name: "event1", time_unix_nano: 1L, attributes: Map([]), dropped_attributes_count: 0 },
    { name: "event2", time_unix_nano: 2L, attributes: Map([]), dropped_attributes_count: 0 },
  ]
  b.bench(fn() {
    let w = ProtoWriter::with_capacity(448)
    encode_attributes(w, 9, attributes)
    let _ = w.to_bytes()
  })
  b.bench(fn() {
    let w = ProtoWriter::with_capacity(448)
    for event in events {
      encode_event(w, event)
    }
    let _ = w.to_bytes()
  })
  b.bench(fn() {
    let w = ProtoWriter::with_capacity(448)
    let kv = w.take_scratch()
    kv.write_string_field(1, "http.request.method")
    kv.write_tag(2, 2)
    let mark = kv.len
    kv.write_varint(4)
    kv.write_tag(1, 2)
    kv.write_varint(3)
    let _ = kv.try_write_ascii_raw("GET")
    w.append_message(9, kv)
    let _ = w.to_bytes()
  })
  b.bench(fn() {
    let w = ProtoWriter::with_capacity(448)
    for i = 0; i < 5; i = i + 1 {
      let kv = w.take_scratch()
      kv.write_string_field(1, "http.request.method")
      w.append_message(9, kv)
    }
    let _ = w.to_bytes()
  })
}
