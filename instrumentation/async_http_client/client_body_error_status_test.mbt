// A response status arrives before the response body is read. If reading the
// body then fails (for example because the server closes a truncated body),
// the client span must still carry the status that was actually received.

///|
struct BodyErrorStatusExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for BodyErrorStatusExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for BodyErrorStatusExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
async test "client span keeps the received status when the body read fails" {
  let exporter : BodyErrorStatusExporter = { spans: Ref([]), }
  let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="client-body-error-status",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("client-body-error-status")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        let headers : @http.Headers = Map([
          (@http.CaseInsensitiveString("content-length"), "100"),
        ])
        conn.send_response(200, "OK", extra_headers=headers)
        conn.write("hello")
        conn.flush()
        conn.close()
      })
    }
    let failed = try {
      let (_response, _body) = @async_http_client.get(
        "http://127.0.0.1:\{port}/truncated",
        tracer~,
      )
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    @async.sleep(100)
    assert_eq(exporter.spans.val.length(), 1)
    let data = exporter.spans.val[0]
    assert_eq(data.status, @api.StatusCode::Error)
    assert_eq(
      data.attributes.get(@sdk.HTTP_RESPONSE_STATUS_CODE),
      Some(@sdk.IntValue(200)),
    )
    assert_true(data.events.length() > 0)
  }
  provider.shutdown()
}
