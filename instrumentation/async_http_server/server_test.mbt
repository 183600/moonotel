// Integration tests for the async HTTP server instrumentation.

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
fn find_span(spans : Array[@sdk.SpanData], name : String) -> @sdk.SpanData? {
  for data in spans {
    if data.name == name {
      return Some(data)
    }
  }
  None
}

///|
suberror HandlerBoom {
  HandlerBoom(String)
} derive(@debug.Debug)

///|
async test "server span continues the propagated trace" {
  let (tracer, exporter) = test_tracer("server-test")
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
    let parent = @api.span_context(
      Array::make(16, 11),
      Array::make(8, 12),
      @api.TRACE_FLAGS_SAMPLED,
    )
    let traceparent = @propagation.format_traceparent(parent)
    let (response, body) = @http.get("http://127.0.0.1:\{port}/items?q=1", headers={
      "traceparent": traceparent,
    })
    assert_eq(response.code, 200)
    assert_eq(body.text(), "ok")
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.name, "GET")
    assert_eq(data.kind, @api.SpanKind::Server)
    assert_eq(data.span_context.trace_id_hex(), parent.trace_id_hex())
    assert_eq(data.parent_span_id, parent.span_id())
    assert_eq(
      data.attributes.get(@sdk.HTTP_REQUEST_METHOD),
      Some(@sdk.StringValue("GET")),
    )
    assert_eq(
      data.attributes.get(@sdk.URL_PATH),
      Some(@sdk.StringValue("/items")),
    )
    assert_eq(
      data.attributes.get(@sdk.URL_QUERY),
      Some(@sdk.StringValue("q=1")),
    )
    assert_eq(
      data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE),
      Some(@sdk.IntValue(200)),
    )
    assert_eq(data.status, @api.StatusCode::Unset)
  }
}

///|
async test "ServerCall::start_span parents children to the request" {
  let (tracer, exporter) = test_tracer("server-test-children")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => {
          match call.start_span("db.query") {
            Some(span) => {
              span.set_attribute("db.system", @sdk.StringValue("testdb"))
              span.end()
            }
            None => ()
          }
          call.respond(200)
        },
        tracer~,
      )
    }
    let (response, _body) = @http.get("http://127.0.0.1:\{port}/children")
    assert_eq(response.code, 200)
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 2)
    let server_span = find_span(exporter.spans.val, "GET").unwrap()
    let child = find_span(exporter.spans.val, "db.query").unwrap()
    assert_eq(child.kind, @api.SpanKind::Internal)
    assert_eq(
      child.span_context.trace_id_hex(),
      server_span.span_context.trace_id_hex(),
    )
    assert_eq(child.parent_span_id, server_span.span_context.span_id())
    assert_eq(
      child.attributes.get("db.system"),
      Some(@sdk.StringValue("testdb")),
    )
  }
}

///|
async test "5xx responses set the server span status to Error" {
  let (tracer, exporter) = test_tracer("server-test-error")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(500, body="oops"),
        tracer~,
      )
    }
    let (response, _body) = @http.get("http://127.0.0.1:\{port}/fail")
    assert_eq(response.code, 500)
    @async.sleep(50)
    let data = exporter.spans.val[0]
    assert_eq(data.status, @api.StatusCode::Error)
    assert_eq(
      data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE),
      Some(@sdk.IntValue(500)),
    )
    assert_eq(
      data.attributes.get(@sdk.ERROR_TYPE),
      Some(@sdk.StringValue("500")),
    )
  }
}

///|
async test "handler exceptions are recorded and end the span" {
  let (tracer, exporter) = test_tracer("server-test-exception")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => {
          let _ = call
          raise HandlerBoom("boom")
        },
        tracer~,
      )
    }
    let outcome = try {
      let (_response, _body) = @http.get("http://127.0.0.1:\{port}/raise")
      true
    } catch {
      _ => false
    }
    let _ = outcome
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.status, @api.StatusCode::Error)
    assert_eq(data.events.length(), 1)
    assert_eq(data.events[0].name, "exception")
    match data.events[0].attributes.get(@sdk.EXCEPTION_MESSAGE) {
      Some(@sdk.StringValue(message)) => assert_true(message.contains("boom"))
      _ => fail("exception.message attribute is missing")
    }
  }
}

///|
test "extract_context parses traceparent, tracestate and baggage" {
  let parent = @api.span_context(
    Array::make(16, 21),
    Array::make(8, 22),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let headers : Map[@http.CaseInsensitiveString, String] = Map([])
  headers.set(
    @http.CaseInsensitiveString("traceparent"),
    @propagation.format_traceparent(parent),
  )
  headers.set(@http.CaseInsensitiveString("tracestate"), "congo=t61rcWkgMzE")
  headers.set(@http.CaseInsensitiveString("baggage"), "user.id=42,note=a%2Cb")
  let context = @async_http_server.extract_context(headers)
  let span_context = context.span_context().unwrap()
  assert_eq(span_context.trace_id_hex(), parent.trace_id_hex())
  assert_eq(span_context.span_id_hex(), parent.span_id_hex())
  assert_eq(span_context.tracestate(), "congo=t61rcWkgMzE")
  assert_eq(context.value("user.id"), Some("42"))
  assert_eq(context.value("note"), Some("a,b"))
}

///|
test "extract_context ignores an invalid tracestate" {
  let parent = @api.span_context(
    Array::make(16, 31),
    Array::make(8, 32),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let headers : Map[@http.CaseInsensitiveString, String] = Map([])
  headers.set(
    @http.CaseInsensitiveString("traceparent"),
    @propagation.format_traceparent(parent),
  )
  headers.set(@http.CaseInsensitiveString("tracestate"), "not a valid state")
  let context = @async_http_server.extract_context(headers)
  assert_eq(context.span_context().unwrap().tracestate(), "")
}

///|
test "extract_context is empty without headers" {
  let headers : Map[@http.CaseInsensitiveString, String] = Map([])
  let context = @async_http_server.extract_context(headers)
  assert_true(context.span_context() is None)
  assert_eq(context.baggage().length(), 0)
}

///|
async test "server propagates tracestate and baggage headers" {
  let (tracer, exporter) = test_tracer("server-test-state")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(200),
        tracer~,
      )
    }
    let parent = @api.span_context(
      Array::make(16, 21),
      Array::make(8, 22),
      @api.TRACE_FLAGS_SAMPLED,
    )
    let (response, _body) = @http.get("http://127.0.0.1:\{port}/state", headers={
      "traceparent": @propagation.format_traceparent(parent),
      "tracestate": "congo=t61rcWkgMzE",
      "baggage": "user.id=42,note=a%2Cb",
    })
    assert_eq(response.code, 200)
    @async.sleep(50)
    let data = exporter.spans.val[0]
    assert_eq(data.span_context.tracestate(), "congo=t61rcWkgMzE")
    assert_eq(data.span_context.trace_id_hex(), parent.trace_id_hex())
    assert_eq(data.parent_span_id, parent.span_id())
  }
}

///|
async test "ServerCall::set_route records http.route and renames the span" {
  let (tracer, exporter) = test_tracer("server-test-route")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => {
          assert_true(call.set_route("/items/:id"))
          call.respond(200)
        },
        tracer~,
      )
    }
    let (response, _body) = @http.get("http://127.0.0.1:\{port}/items/42")
    assert_eq(response.code, 200)
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.name, "GET /items/:id")
    assert_eq(
      data.attributes.get(@sdk.HTTP_ROUTE),
      Some(@sdk.StringValue("/items/:id")),
    )
  }
}

///|
async test "ServerCall::set_route is a no-op without tracing" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => {
        assert_false(call.set_route("/plain"))
        call.respond(204)
      })
    }
    let (response, _body) = @http.get("http://127.0.0.1:\{port}/plain")
    assert_eq(response.code, 204)
  }
}

///|
async test "server runs untraced when no tracer is available" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(server, call => call.respond(204))
    }
    let (response, _body) = @http.get("http://127.0.0.1:\{port}/plain")
    assert_eq(response.code, 204)
  }
}
