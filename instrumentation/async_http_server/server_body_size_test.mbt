// Tests for the HTTP response body size semantic-convention attribute
// recorded by the server instrumentation.

///|
struct BodySizeServerExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for BodySizeServerExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for BodySizeServerExporter with fn shutdown(self) {
  let _ = self
}

///|
fn body_size_server_tracer(
  scope : String,
) -> (@sdk.Tracer, BodySizeServerExporter) {
  let exporter : BodySizeServerExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="server-body-size-test",
  ).with_span_processor(processor)
  (provider.get_tracer(scope), exporter)
}

///|
async test "server span records the response body size in UTF-8 bytes" {
  let (tracer, exporter) = body_size_server_tracer("server-body-size")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(200, body="héllo"),
        tracer~,
      )
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/greet")
    assert_eq(response.code, 200)
    assert_eq(body.text(), "héllo")
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    // `é` needs two UTF-8 bytes, so the body is six bytes, not five
    // characters.
    assert_eq(
      data.attributes.get(@sdk.HTTP_RESPONSE_BODY_SIZE),
      Some(@sdk.IntValue(6)),
    )
  }
}

///|
async test "server span omits the response body size without a body" {
  let (tracer, exporter) = body_size_server_tracer("server-body-size-empty")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(204),
        tracer~,
      )
    }
    let (response, _body) = @http.get("http://127.0.0.1:\{port}/none")
    assert_eq(response.code, 204)
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.attributes.get(@sdk.HTTP_RESPONSE_BODY_SIZE), None)
  }
}

///|
async test "server suppresses a response body for reset-content responses" {
  let (tracer, exporter) = body_size_server_tracer("server-reset-content-body")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(205, body="ignored"),
        tracer~,
      )
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/reset")
    assert_eq(response.code, 205)
    assert_eq(body.text(), "")
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE), Some(@sdk.IntValue(205)))
    assert_eq(data.attributes.get(@sdk.HTTP_RESPONSE_BODY_SIZE), None)
  }
}

///|
async test "server suppresses a response body for HEAD requests" {
  let (tracer, exporter) = body_size_server_tracer("server-head-body")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(200, body="ignored"),
        tracer~,
      )
    }
    let client = @http.Client("http://127.0.0.1:\{port}")
    defer client.close()
    client.request(@http.Head, "/head")
    let response = client.end_request()
    assert_eq(response.code, 200)
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE), Some(@sdk.IntValue(200)))
    assert_eq(data.attributes.get(@sdk.HTTP_RESPONSE_BODY_SIZE), None)
    assert_eq(data.status, @api.StatusCode::Unset)
  }
}

///|
async test "server suppresses a response body for no-content responses" {
  let (tracer, exporter) = body_size_server_tracer("server-no-content-body")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(204, body="ignored"),
        tracer~,
      )
    }
    let (response, body) = @http.get("http://127.0.0.1:\{port}/none")
    assert_eq(response.code, 204)
    assert_eq(body.text(), "")
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE), Some(@sdk.IntValue(204)))
    assert_eq(data.attributes.get(@sdk.HTTP_RESPONSE_BODY_SIZE), None)
    assert_eq(data.status, @api.StatusCode::Unset)
  }
}

///|
async test "server records the status when the client aborts the response body" {
  let (tracer, exporter) = body_size_server_tracer("server-aborted-body")
  // Large enough that the server cannot finish writing it into the socket
  // buffer before the client closes the connection.
  let large_body = "x".repeat(2 * 1024 * 1024)
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(200, body=large_body),
        tracer~,
      )
    }
    let client = @http.Client("http://127.0.0.1:\{port}")
    client.request(@http.Get, "/large")
    let response = client.end_request()
    assert_eq(response.code, 200)
    // Do not consume the body; close while the server is still writing it.
    client.close()
    let mut waited = 0
    while exporter.spans.val.length() == 0 && waited < 2000 {
      @async.sleep(10)
      waited = waited + 10
    }
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(
      data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE),
      Some(@sdk.IntValue(200)),
    )
  }
}
