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
