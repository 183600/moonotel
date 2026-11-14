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
  request_body? : &@io.Data,
  received_content_length? : Ref[String?],
) -> @sdk.SpanData {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, body, connection) => {
        let _ = body.read_all()
        match received_content_length {
          Some(received) =>
            received.val = request.headers.get(
              @http.CaseInsensitiveString("content-length"),
            )
          None => ()
        }
        let headers : @http.Headers = Map([
          (@http.CaseInsensitiveString("X-Reply"), "captured"),
        ])
        connection.send_response(200, "OK", extra_headers=headers)
      })
    }
    let url = "http://127.0.0.1:\{port}/capture"
    let (response, _body) = match request_body {
      Some(body) =>
        @async_http_client.post(
          url,
          body,
          headers=request_headers,
          tracer~,
          context=@context.Context::root(),
        )
      None =>
        @async_http_client.get(
          url,
          headers=request_headers,
          tracer~,
          context=@context.Context::root(),
        )
    }
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
  let data = captured_client_span(tracer, exporter, {
    "X-Custom": "request-value",
  })
  assert_eq(data.attributes.get("http.request.header.x-custom"), None)
  assert_eq(data.attributes.get("http.response.header.x-reply"), None)
  // Configured request and response headers are captured.
  @env.set_env_var(@http_header_capture.ENV_CLIENT_REQUEST_HEADERS, "X-Custom")
  @env.set_env_var(@http_header_capture.ENV_CLIENT_RESPONSE_HEADERS, "X-Reply")
  let (tracer, exporter) = test_tracer("client-header-capture")
  let data = captured_client_span(tracer, exporter, {
    "X-Custom": "request-value",
  })
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
  let data = captured_client_span(tracer, exporter, {
    "X-One": "1",
    "Bad Header": "dropped",
    "X-CRLF": "a\r\nb",
  })
  assert_eq(
    data.attributes.get("http.request.header.x-one"),
    Some(@sdk.StringArrayValue(["1"])),
  )
  assert_eq(
    data.attributes.get("http.response.header.x-reply"),
    Some(@sdk.StringArrayValue(["captured"])),
  )
  // The transport drops invalid header names and strips CR/LF from values;
  // the capture must show that sanitized wire form.
  assert_eq(data.attributes.get("http.request.header.bad header"), None)
  assert_eq(
    data.attributes.get("http.request.header.x-crlf"),
    Some(@sdk.StringArrayValue(["ab"])),
  )
  // The transport adds Accept-Encoding to a request that does not set one.
  match data.attributes.get("http.request.header.accept-encoding") {
    Some(@sdk.StringArrayValue(values)) => {
      assert_eq(values.length(), 1)
      assert_true(values[0].contains("gzip"))
    }
    _ => fail("expected the transport Accept-Encoding header to be captured")
  }
  match data.attributes.get("http.request.header.traceparent") {
    Some(@sdk.StringArrayValue(values)) => assert_eq(values.length(), 1)
    _ => fail("expected the injected traceparent header to be captured")
  }
  // The HTTP client adds `Host` and `User-Agent` to the header map itself, so
  // the wildcard must see those actually-sent headers too.
  match data.attributes.get("http.request.header.host") {
    Some(@sdk.StringArrayValue(values)) => {
      assert_eq(values.length(), 1)
      assert_true(values[0].contains("127.0.0.1"))
    }
    _ => fail("expected the Host header added by the client to be captured")
  }
  match data.attributes.get("http.request.header.user-agent") {
    Some(@sdk.StringArrayValue(values)) => assert_eq(values.length(), 1)
    _ =>
      fail("expected the User-Agent header added by the client to be captured")
  }
  // A caller-supplied Content-Length is written by the transport, which also
  // drops the caller's Transfer-Encoding. Capture must show that fixed-length
  // form instead of the chunked framing used for unknown-length bodies.
  let (tracer, exporter) = test_tracer("client-header-capture")
  let received_content_length : Ref[String?] = Ref(None)
  let data = captured_client_span(
    tracer,
    exporter,
    { "Content-Length": "7", "Transfer-Encoding": "gzip" },
    request_body="payload",
    received_content_length=received_content_length,
  )
  assert_eq(received_content_length.val, Some("7"))
  assert_eq(
    data.attributes.get("http.request.header.content-length"),
    Some(@sdk.StringArrayValue(["7"])),
  )
  assert_eq(
    data.attributes.get("http.request.header.transfer-encoding"),
    None,
  )
  // Without Content-Length the transport frames the body with chunked
  // encoding, even when the caller attempted to set Transfer-Encoding.
  let (tracer, exporter) = test_tracer("client-header-capture")
  let data = captured_client_span(
    tracer,
    exporter,
    { "Transfer-Encoding": "gzip" },
    request_body="payload",
  )
  assert_eq(
    data.attributes.get("http.request.header.transfer-encoding"),
    Some(@sdk.StringArrayValue(["chunked"])),
  )
  // An unusable Content-Length is ignored, so the transport falls back to
  // chunked framing instead of aborting the request.
  let (tracer, exporter) = test_tracer("client-header-capture")
  let received_content_length : Ref[String?] = Ref(None)
  let data = captured_client_span(
    tracer,
    exporter,
    { "Content-Length": "not-a-number" },
    request_body="payload",
    received_content_length=received_content_length,
  )
  assert_eq(received_content_length.val, None)
  assert_eq(
    data.attributes.get("http.request.header.content-length"),
    None,
  )
  assert_eq(
    data.attributes.get("http.request.header.transfer-encoding"),
    Some(@sdk.StringArrayValue(["chunked"])),
  )
}
