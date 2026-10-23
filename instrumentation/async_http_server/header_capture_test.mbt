// Integration tests for opt-in HTTP header capture on server spans.
//
// All env-driven checks live in a single async test: the async test driver
// runs tests concurrently, so several tests mutating the same environment
// variables could observe each other's updates.

///|
struct HeaderCaptureExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for HeaderCaptureExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for HeaderCaptureExporter with fn shutdown(self) {
  let _ = self
}

///|
fn header_capture_tracer() -> (@sdk.Tracer, HeaderCaptureExporter) {
  let exporter : HeaderCaptureExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="header-capture-test",
  ).with_span_processor(processor)
  (provider.get_tracer("header-capture-test"), exporter)
}

// Start a server whose handler answers with the given response headers, issue
// one request and return the SERVER span data recorded for it.

///|
async fn captured_server_span(
  tracer : @sdk.Tracer,
  exporter : HeaderCaptureExporter,
  request_headers : @http.Headers,
  response_headers : Map[String, String],
) -> @sdk.SpanData {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(200, body="ok", headers=response_headers),
        tracer~,
      )
    }
    let (response, _body) = @http.get(
      "http://127.0.0.1:\{port}/capture",
      headers=request_headers,
    )
    assert_eq(response.code, 200)
    @async.sleep(50)
  }
  assert_eq(exporter.spans.val.length(), 1)
  exporter.spans.val[0]
}

///|
async test "server header capture follows the configured environment" {
  @env.unset_env_var(@http_header_capture.ENV_SERVER_REQUEST_HEADERS)
  @env.unset_env_var(@http_header_capture.ENV_SERVER_RESPONSE_HEADERS)
  defer {
    @env.unset_env_var(@http_header_capture.ENV_SERVER_REQUEST_HEADERS)
    @env.unset_env_var(@http_header_capture.ENV_SERVER_RESPONSE_HEADERS)
  }
  // Header capture is disabled by default.
  let (tracer, exporter) = header_capture_tracer()
  let data = captured_server_span(
    tracer,
    exporter,
    { "X-Custom": "request-value" },
    { "X-Reply": "captured" },
  )
  assert_eq(data.attributes.get("http.request.header.x-custom"), None)
  assert_eq(data.attributes.get("http.response.header.x-reply"), None)
  // Configured names are captured case-insensitively and lower-cased.
  @env.set_env_var(
    @http_header_capture.ENV_SERVER_REQUEST_HEADERS,
    "X-Custom, User-Agent",
  )
  @env.set_env_var(@http_header_capture.ENV_SERVER_RESPONSE_HEADERS, "X-Reply")
  let (tracer, exporter) = header_capture_tracer()
  let data = captured_server_span(
    tracer,
    exporter,
    { "X-Custom": "request-value", "User-Agent": "capture-test/1.0" },
    { "X-Reply": "captured" },
  )
  assert_eq(
    data.attributes.get("http.request.header.x-custom"),
    Some(@sdk.StringArrayValue(["request-value"])),
  )
  assert_eq(
    data.attributes.get("http.request.header.user-agent"),
    Some(@sdk.StringArrayValue(["capture-test/1.0"])),
  )
  assert_eq(
    data.attributes.get("http.response.header.x-reply"),
    Some(@sdk.StringArrayValue(["captured"])),
  )
  // The wildcard captures every request and response header.
  @env.set_env_var(@http_header_capture.ENV_SERVER_REQUEST_HEADERS, "*")
  @env.set_env_var(@http_header_capture.ENV_SERVER_RESPONSE_HEADERS, "*")
  let (tracer, exporter) = header_capture_tracer()
  let data = captured_server_span(
    tracer,
    exporter,
    { "X-One": "1", "X-Two": "2" },
    {
      "X-Reply": "captured",
      "Bad Header": "dropped",
      "X-CRLF": "a\r\nb",
    },
  )
  assert_eq(
    data.attributes.get("http.request.header.x-one"),
    Some(@sdk.StringArrayValue(["1"])),
  )
  assert_eq(
    data.attributes.get("http.request.header.x-two"),
    Some(@sdk.StringArrayValue(["2"])),
  )
  assert_eq(
    data.attributes.get("http.response.header.x-reply"),
    Some(@sdk.StringArrayValue(["captured"])),
  )
  // The transport drops invalid response header names, strips CR/LF from
  // values and adds the framing it actually writes.
  assert_eq(data.attributes.get("http.response.header.bad header"), None)
  assert_eq(
    data.attributes.get("http.response.header.x-crlf"),
    Some(@sdk.StringArrayValue(["ab"])),
  )
  assert_eq(
    data.attributes.get("http.response.header.transfer-encoding"),
    Some(@sdk.StringArrayValue(["chunked"])),
  )
}
