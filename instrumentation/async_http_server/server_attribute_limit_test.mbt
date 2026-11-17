// Host attributes are passed to span creation so samplers can see them. They
// must not be applied a second time after the span starts: with an attribute
// count limit that discarded them, the second attempt would count them as
// dropped twice.

///|
async test "server span does not double count dropped host attributes" {
  let exporter : RecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="server-attribute-limit",
  ).with_span_processor(processor).with_span_limits(
    @sdk.SpanLimits::new(attribute_count_limit=0),
  )
  let tracer = provider.get_tracer("server-attribute-limit")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(200, body="ok"),
        tracer~,
      )
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/limit")
    assert_eq(response.code, 200)
    assert_eq(body.text(), "ok")
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.attributes.length(), 0)
    // Thirteen attributes recorded at span creation (method, scheme,
    // transport, protocol name, protocol version, path, server address,
    // server port, peer address, peer port, client address, client port and
    // user agent), plus the response status and body size. The host
    // attributes are among the thirteen, not additional.
    assert_eq(data.dropped_attributes_count, 15)
  }
}
