// Integration tests for the async HTTP client instrumentation, driven against
// real loopback HTTP servers.

///|
struct RecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for RecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for RecordingExporter with fn shutdown(self) {
  let _ = self
}

///|
fn test_tracer(scope : String) -> (@sdk.Tracer, RecordingExporter) {
  let exporter : RecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="instrumentation-test",
  ).with_span_processor(processor)
  (provider.get_tracer(scope), exporter)
}

///|
test "split_url handles schemes, ports, userinfo and IPv6 hosts" {
  assert_eq(
    @async_http_client.split_url("https://example.com/x"),
    ("example.com", 443),
  )
  assert_eq(
    @async_http_client.split_url("http://example.com:8080/x"),
    ("example.com", 8080),
  )
  assert_eq(
    @async_http_client.split_url("http://user:pass@host.test:9000/"),
    ("host.test", 9000),
  )
  assert_eq(
    @async_http_client.split_url("http://[::1]:4318/v1/traces"),
    ("[::1]", 4318),
  )
  assert_eq(@async_http_client.split_url("example.com"), ("example.com", 80))
  assert_eq(
    @async_http_client.split_url("HTTPS://example.com/x"),
    ("example.com", 443),
  )
}

///|
test "split_url ignores query and fragment when no path is present" {
  assert_eq(
    @async_http_client.split_url("http://example.com?x=1"),
    ("example.com", 80),
  )
  assert_eq(
    @async_http_client.split_url("https://example.com?x=1"),
    ("example.com", 443),
  )
  assert_eq(
    @async_http_client.split_url("http://example.com:8080?x=1"),
    ("example.com", 8080),
  )
  assert_eq(
    @async_http_client.split_url("http://example.com#frag"),
    ("example.com", 80),
  )
  assert_eq(
    @async_http_client.split_url("http://user:pass@host.test:9000?x=1"),
    ("host.test", 9000),
  )
  assert_eq(@async_http_client.split_url("http://[::1]?x=1"), ("[::1]", 80))
}

///|
test "split_url ignores invalid scheme separators" {
  assert_eq(
    @async_http_client.split_url("/foo://user:pass@host"),
    ("", 80),
  )
  assert_eq(
    @async_http_client.split_url("example.com?next=http://user:pass@host"),
    ("example.com", 80),
  )
}

///|
test "split_scheme lower-cases and validates schemes" {
  assert_eq(@async_http_client.split_scheme("https://example.com/x"), "https")
  assert_eq(@async_http_client.split_scheme("HTTP://example.com"), "http")
  assert_eq(@async_http_client.split_scheme("http+unix://sock"), "http+unix")
  assert_eq(@async_http_client.split_scheme("example.com/path"), "")
  assert_eq(@async_http_client.split_scheme("1http://example.com"), "")
  assert_eq(@async_http_client.split_scheme("http://"), "http")
}

///|
async test "get creates a client span and injects traceparent" {
  let (tracer, exporter) = test_tracer("client-test")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let traceparent : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        traceparent.val = request.headers
          .get(@http.CaseInsensitiveString("traceparent"))
          .unwrap_or("")
        conn.send_response(200, "OK")
      })
    }
    let url = "http://127.0.0.1:\{port}/hello"
    let (response, _body) = @async_http_client.get(
      url,
      tracer~,
      context=@context.Context::root(),
    )
    assert_eq(response.code, 200)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.name, "GET")
    assert_eq(data.kind, @api.SpanKind::Client)
    assert_eq(data.parent_span_id.length(), 0)
    let expected = "00-" +
      data.span_context.trace_id_hex() +
      "-" +
      data.span_context.span_id_hex() +
      "-01"
    assert_eq(traceparent.val, expected)
    assert_eq(
      data.attributes.get(@sdk.HTTP_REQUEST_METHOD),
      Some(@sdk.StringValue("GET")),
    )
    assert_eq(data.attributes.get(@sdk.URL_FULL), Some(@sdk.StringValue(url)))
    assert_eq(
      data.attributes.get(@sdk.URL_SCHEME),
      Some(@sdk.StringValue("http")),
    )
    assert_eq(
      data.attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("127.0.0.1")),
    )
    assert_eq(
      data.attributes.get(@sdk.SERVER_PORT),
      Some(@sdk.IntValue(port.to_int64())),
    )
    assert_eq(
      data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE),
      Some(@sdk.IntValue(200)),
    )
    assert_eq(data.status, @api.StatusCode::Unset)
  }
}

///|
async test "client span records the url path and query" {
  let (tracer, exporter) = test_tracer("client-url-parts")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(200, "OK")
      })
    }
    let (response, _body) = @async_http_client.get(
      "http://127.0.0.1:\{port}/search?q=moonbit&lang=zh",
      tracer~,
      context=@context.Context::root(),
    )
    assert_eq(response.code, 200)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.URL_PATH),
      Some(@sdk.StringValue("/search")),
    )
    assert_eq(
      data.attributes.get(@sdk.URL_QUERY),
      Some(@sdk.StringValue("q=moonbit&lang=zh")),
    )
  }
}

///|
async test "client span continues the current trace context" {
  let (tracer, exporter) = test_tracer("client-test-parent")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(200, "OK")
      })
    }
    let parent = @api.span_context(
      Array::make(16, 5),
      Array::make(8, 6),
      @api.TRACE_FLAGS_SAMPLED,
    )
    let previous = @context.attach(@context.Context::root().with_span(parent))
    defer @context.detach(previous)
    let (response, _body) = @async_http_client.get(
      "http://127.0.0.1:\{port}/child",
      tracer~,
    )
    assert_eq(response.code, 200)
    let data = exporter.spans.val[0]
    assert_eq(data.span_context.trace_id_hex(), parent.trace_id_hex())
    assert_eq(data.parent_span_id, parent.span_id())
  }
}

///|
async test "client span is marked as error for 5xx responses" {
  let (tracer, exporter) = test_tracer("client-test-error")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(503, "Service Unavailable")
      })
    }
    let (response, _body) = @async_http_client.get(
      "http://127.0.0.1:\{port}/down",
      tracer~,
    )
    assert_eq(response.code, 503)
    let data = exporter.spans.val[0]
    assert_eq(data.status, @api.StatusCode::Error)
    assert_eq(
      data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE),
      Some(@sdk.IntValue(503)),
    )
    assert_eq(
      data.attributes.get(@sdk.ERROR_TYPE),
      Some(@sdk.StringValue("503")),
    )
  }
}

///|
async test "post sends the request body" {
  let (tracer, exporter) = test_tracer("client-test-post")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let received : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        received.val = body.read_all().text()
        conn.send_response(201, "Created")
      })
    }
    let (response, _body) = @async_http_client.post(
      "http://127.0.0.1:\{port}/items",
      "payload",
      tracer~,
    )
    assert_eq(response.code, 201)
    assert_eq(received.val, "payload")
    assert_eq(exporter.spans.val[0].name, "POST")
    assert_eq(
      exporter.spans.val[0].attributes.get(@sdk.HTTP_REQUEST_METHOD),
      Some(@sdk.StringValue("POST")),
    )
  }
}

///|
async test "requests are untraced when no tracer is available" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(200, "OK")
      })
    }
    let (response, _body) = @async_http_client.get(
      "http://127.0.0.1:\{port}/plain",
    )
    assert_eq(response.code, 200)
  }
}

///|
async test "client propagates tracestate and baggage" {
  let (tracer, exporter) = test_tracer("client-test-state")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let received_tracestate : Ref[String] = Ref("")
    let received_baggage : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        received_tracestate.val = request.headers
          .get(@http.CaseInsensitiveString("tracestate"))
          .unwrap_or("")
        received_baggage.val = request.headers
          .get(@http.CaseInsensitiveString("baggage"))
          .unwrap_or("")
        conn.send_response(200, "OK")
      })
    }
    let parent = @api.span_context(
      Array::make(16, 5),
      Array::make(8, 6),
      @api.TRACE_FLAGS_SAMPLED,
      tracestate="congo=t61rcWkgMzE",
    )
    let request_context = @context.Context::root()
      .with_span(parent)
      .with_value("user.id", "42")
    let (response, _body) = @async_http_client.get(
      "http://127.0.0.1:\{port}/state",
      tracer~,
      context=request_context,
    )
    assert_eq(response.code, 200)
    assert_eq(received_tracestate.val, "congo=t61rcWkgMzE")
    assert_eq(received_baggage.val, "user.id=42")
    let data = exporter.spans.val[0]
    assert_eq(data.span_context.tracestate(), "congo=t61rcWkgMzE")
    assert_eq(data.parent_span_id, parent.span_id())
  }
}

///|
async test "instrumented client and server produce a connected trace" {
  let (tracer, exporter) = test_tracer("client-test-e2e")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @server.run_server_on(
        server,
        call => call.respond(200, body="connected"),
        tracer~,
      )
    }
    let url = "http://127.0.0.1:\{port}/e2e"
    let (response, body) = @async_http_client.get(url, tracer~)
    assert_eq(response.code, 200)
    assert_eq(body.text(), "connected")
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 2)
    let mut client_span : @sdk.SpanData? = None
    let mut server_span : @sdk.SpanData? = None
    for data in exporter.spans.val {
      if data.kind == @api.SpanKind::Client {
        client_span = Some(data)
      } else if data.kind == @api.SpanKind::Server {
        server_span = Some(data)
      }
    }
    let client = client_span.unwrap()
    let server_data = server_span.unwrap()
    assert_eq(
      server_data.span_context.trace_id_hex(),
      client.span_context.trace_id_hex(),
    )
    assert_eq(server_data.parent_span_id, client.span_context.span_id())
    assert_eq(
      server_data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE),
      Some(@sdk.IntValue(200)),
    )
  }
}

///|
async test "client span records error.type when the request fails" {
  let (tracer, exporter) = test_tracer("client-test-exception")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((
        _request,
        _body,
        conn,
        // Drop the connection without a response so the client request fails.
      ) => conn.close())
    }
    let failed = try {
      let (_response, _body) = @async_http_client.get(
        "http://127.0.0.1:\{port}/reset",
        tracer~,
      )
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.status, @api.StatusCode::Error)
    match data.attributes.get(@sdk.ERROR_TYPE) {
      Some(@sdk.StringValue(name)) => assert_true(name.length() > 0)
      _ => fail("error.type attribute is missing")
    }
    assert_eq(data.events.length(), 1)
    assert_eq(data.events[0].name, "exception")
  }
}

///|
test "split_url rejects non-decimal and out-of-range ports" {
  assert_eq(
    @async_http_client.split_url("http://example.com:0x1F90/x"),
    ("example.com", -1),
  )
  assert_eq(
    @async_http_client.split_url("http://example.com:1_0/x"),
    ("example.com", -1),
  )
  assert_eq(
    @async_http_client.split_url("http://example.com:+80/x"),
    ("example.com", -1),
  )
  assert_eq(
    @async_http_client.split_url("http://example.com:65536/x"),
    ("example.com", -1),
  )
  assert_eq(
    @async_http_client.split_url("http://example.com:00080/x"),
    ("example.com", 80),
  )
}
