// An unpaired UTF-16 surrogate in a response body cannot be encoded as UTF-8.
// The instrumentation substitutes U+FFFD instead of aborting the server task.

///|
struct SurrogateBodyExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for SurrogateBodyExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for SurrogateBodyExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
async test "server response body replaces unpaired surrogates with U+FFFD" {
  let high = String::from_array([(0xD800).unsafe_to_char()])
  let low = String::from_array([(0xDC00).unsafe_to_char()])
  let replacement = (0xFFFD).unsafe_to_char().to_string()
  let exporter : SurrogateBodyExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="server-surrogate-test",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("server-surrogate-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(200, body="a" + high + "b" + low + "c"),
        tracer~,
      )
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/surrogate")
    assert_eq(response.code, 200)
    let expected = "a" + replacement + "b" + replacement + "c"
    assert_eq(body.text(), expected)
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    assert_eq(
      exporter.spans.val[0].attributes.get(@sdk.HTTP_RESPONSE_BODY_SIZE),
      Some(@sdk.IntValue(9)),
    )
  }
}

///|
async test "server response header values replace unpaired surrogates" {
  let high = String::from_array([(0xD800).unsafe_to_char()])
  let low = String::from_array([(0xDC00).unsafe_to_char()])
  let replacement = (0xFFFD).unsafe_to_char().to_string()
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        let headers : Map[String, String] = Map([
          ("x-surrogate", "v" + high + "w" + low + "x"),
        ])
        call.respond(200, headers~)
      })
    }
    let (response, _body) = @http.get("http://127.0.0.1:\{port}/header")
    assert_eq(response.code, 200)
    assert_eq(
      response.headers.get(@http.CaseInsensitiveString("x-surrogate")),
      Some("v" + replacement + "w" + replacement + "x"),
    )
  }
}
