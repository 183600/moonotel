// Integration tests for the HEAD / PATCH / OPTIONS client helpers.

///|
struct MethodsRecordingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for MethodsRecordingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for MethodsRecordingExporter with fn shutdown(self) {
  let _ = self
}

///|
fn methods_test_tracer(
  scope : String,
) -> (@sdk.Tracer, MethodsRecordingExporter) {
  let exporter : MethodsRecordingExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(service_name="client-methods").with_span_processor(
    processor,
  )
  (provider.get_tracer(scope), exporter)
}

///|
async test "head patch and options use the right methods" {
  let (tracer, exporter) = methods_test_tracer("client-methods")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let methods : Ref[Array[String]] = Ref([])
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, body, conn) => {
        methods.val.push(@async_http_client.http_method_name(request.meth))
        if request.meth == @http.RequestMethod::Patch {
          let _ = body.read_all()
        }
        conn.send_response(200, "OK")
      })
    }
    let url = "http://127.0.0.1:\{port}/methods"
    let (head_response, _) = @async_http_client.head(url, tracer~)
    let (patch_response, _) = @async_http_client.patch(url, "payload", tracer~)
    let (options_response, _) = @async_http_client.options(url, tracer~)
    assert_eq(head_response.code, 200)
    assert_eq(patch_response.code, 200)
    assert_eq(options_response.code, 200)
    assert_eq(methods.val, ["HEAD", "PATCH", "OPTIONS"])
    assert_eq(exporter.spans.val.length(), 3)
    assert_eq(exporter.spans.val[0].name, "HEAD")
    assert_eq(exporter.spans.val[1].name, "PATCH")
    assert_eq(exporter.spans.val[2].name, "OPTIONS")
    assert_eq(
      exporter.spans.val[1].attributes.get(@sdk.HTTP_REQUEST_METHOD),
      Some(@sdk.StringValue("PATCH")),
    )
  }
}

///|
async test "trace and connect use the right methods" {
  let (tracer, exporter) = methods_test_tracer("client-methods")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let methods : Ref[Array[String]] = Ref([])
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        methods.val.push(@async_http_client.http_method_name(request.meth))
        if request.meth == @http.RequestMethod::Connect {
          conn.send_response(405, "Method Not Allowed")
        } else {
          conn.send_response(200, "OK")
        }
      })
    }
    let url = "http://127.0.0.1:\{port}/methods"
    let (trace_response, _) = @async_http_client.trace(url, tracer~)
    let (connect_response, _) = @async_http_client.connect(url, tracer~)
    assert_eq(trace_response.code, 200)
    assert_eq(connect_response.code, 405)
    assert_eq(methods.val, ["TRACE", "CONNECT"])
    assert_eq(exporter.spans.val.length(), 2)
    assert_eq(exporter.spans.val[0].name, "TRACE")
    assert_eq(exporter.spans.val[1].name, "CONNECT")
    assert_eq(
      exporter.spans.val[0].attributes.get(@sdk.HTTP_REQUEST_METHOD),
      Some(@sdk.StringValue("TRACE")),
    )
    assert_eq(
      exporter.spans.val[1].attributes.get(@sdk.HTTP_REQUEST_METHOD),
      Some(@sdk.StringValue("CONNECT")),
    )
    assert_eq(
      exporter.spans.val[1].status,
      @api.StatusCode::Error,
    )
  }
}

///|
async test "connect uses an authority-form request target" {
  let (tracer, exporter) = methods_test_tracer("client-connect-form")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let seen_target : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        if request.meth == @http.RequestMethod::Connect {
          seen_target.val = request.path
        }
        conn.send_response(405, "Method Not Allowed")
      })
    }
    let url = "http://127.0.0.1:\{port}/target"
    let (response, _) = @async_http_client.connect(url, tracer~)
    assert_eq(response.code, 405)
    assert_eq(seen_target.val, "127.0.0.1:\{port}")
    assert_eq(exporter.spans.val.length(), 1)
  }
}

///|
async test "put sends the request body and records the method" {
  let (tracer, exporter) = methods_test_tracer("client-methods")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let received : Ref[String] = Ref("")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, body, conn) => {
        if request.meth == @http.RequestMethod::Put {
          received.val = body.read_all().text()
        }
        conn.send_response(200, "OK")
      })
    }
    let url = "http://127.0.0.1:\{port}/put"
    let (response, _) = @async_http_client.put(url, "payload", tracer~)
    assert_eq(response.code, 200)
    assert_eq(received.val, "payload")
    assert_eq(exporter.spans.val.length(), 1)
    assert_eq(exporter.spans.val[0].name, "PUT")
    assert_eq(
      exporter.spans.val[0].attributes.get(@sdk.HTTP_REQUEST_METHOD),
      Some(@sdk.StringValue("PUT")),
    )
    assert_eq(
      exporter.spans.val[0].attributes.get(@sdk.HTTP_REQUEST_BODY_SIZE),
      Some(@sdk.IntValue(7)),
    )
  }
}
