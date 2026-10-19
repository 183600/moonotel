// Integration tests for opt-in HTTP header capture on client spans.
//
// All env-driven checks live in a single async test: the async test driver
// runs tests concurrently, so several tests mutating the same environment
// variables could observe each other's updates.

// Perform one instrumented request against a raw loopback server and return
// the exported client span data.

///|
async fn captured_client_span(
  tracer : @sdk.Tracer,
  exporter : RecordingExporter,
  request_headers : Map[String, String],
) -> @sdk.SpanData {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, connection) => {
        let headers : @http.Headers = Map([
          (@http.CaseInsensitiveString("X-Reply"), "captured"),
        ])
        connection.send_response(200, "OK", extra_headers=headers)
      })
    }
    let (response, _body) = @async_http_client.get(
      "http://127.0.0.1:\{port}/capture",
      headers=request_headers,
      tracer~,
      context=@context.Context::root(),
    )
    assert_eq(response.code, 200)
  }
  assert_eq(exporter.spans.val.length(), 1)
  exporter.spans.val[0]
}

///|
async test "client header capture follows the configured environment" {
  @env.unset_env_var(@http_header_capture.ENV_CLIENT_REQUEST_HEADERS)
  @env.unset_env_var(@http_header_capture.ENV_CLIENT_RESPONSE_HEADERS)
  defer {
    @env.unset_env_var(@http_header_capture.ENV_CLIENT_REQUEST_HEADERS)
    @env.unset_env_var(@http_header_capture.ENV_CLIENT_RESPONSE_HEADERS)
  }
  // Header capture is disabled by default.
  let (tracer, exporter) = test_tracer("client-header-capture")
  let data = captured_client_span(
    tracer,
    exporter,
    { "X-Custom": "request-value" },
  )
  assert_eq(data.attributes.get("http.request.header.x-custom"), None)
  assert_eq(data.attributes.get("http.response.header.x-reply"), None)
  // Configured request and response headers are captured.
  @env.set_env_var(
    @http_header_capture.ENV_CLIENT_REQUEST_HEADERS,
    "X-Custom",
  )
  @env.set_env_var(@http_header_capture.ENV_CLIENT_RESPONSE_HEADERS, "X-Reply")
  let (tracer, exporter) = test_tracer("client-header-capture")
  let data = captured_client_span(
    tracer,
    exporter,
    { "X-Custom": "request-value" },
  )
  assert_eq(
    data.attributes.get("http.request.header.x-custom"),
    Some(@sdk.StringArrayValue(["request-value"])),
  )
  assert_eq(
    data.attributes.get("http.response.header.x-reply"),
    Some(@sdk.StringArrayValue(["captured"])),
  )
  // The wildcard also captures the injected trace-context headers.
  @env.set_env_var(@http_header_capture.ENV_CLIENT_REQUEST_HEADERS, "*")
  @env.set_env_var(@http_header_capture.ENV_CLIENT_RESPONSE_HEADERS, "*")
  let (tracer, exporter) = test_tracer("client-header-capture")
  let data = captured_client_span(tracer, exporter, { "X-One": "1" })
  assert_eq(
    data.attributes.get("http.request.header.x-one"),
    Some(@sdk.StringArrayValue(["1"])),
  )
  assert_eq(
    data.attributes.get("http.response.header.x-reply"),
    Some(@sdk.StringArrayValue(["captured"])),
  )
  match data.attributes.get("http.request.header.traceparent") {
    Some(@sdk.StringArrayValue(values)) => assert_eq(values.length(), 1)
    _ => fail("expected the injected traceparent header to be captured")
  }
}
