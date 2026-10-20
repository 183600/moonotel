// Blackbox test for case-insensitive protocol/compression handling in the
// async OTLP/HTTP exporter.

///|
fn mixed_case_span() -> @sdk.SpanData {
  let context = @api.span_context(
    Array::make(16, 11),
    Array::make(8, 13),
    @api.TRACE_FLAGS_SAMPLED,
  )
  {
    name: "mixed-case",
    span_context: context,
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map([]),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(Map([])),
    scope_name: "mixed-case",
    scope_version: "",
  }
}

///|
async test "async exporter accepts mixed-case protocol and compression" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let content_type : Ref[String] = Ref("")
    let content_encoding : Ref[String] = Ref("")
    let body : Ref[Bytes] = Ref(b"")
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, request_body, conn) => {
        content_type.val = match
          request.headers.get(@http.CaseInsensitiveString("content-type")) {
          Some(value) => value
          None => ""
        }
        content_encoding.val = match
          request.headers.get(@http.CaseInsensitiveString("content-encoding")) {
          Some(value) => value
          None => ""
        }
        body.val = request_body.read_all().binary()
        conn.send_response(200, "OK")
      })
    }
    let base = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
    )
    let config : @otlp.OtlpHttpConfig = {
      ..base,
      protocol: "HTTP/JSON",
      compression: "GZIP",
    }
    let result = @otlp_async.export_spans(config, [mixed_case_span()])
    assert_true(result.is_success())
    assert_eq(content_type.val, "application/json")
    assert_eq(content_encoding.val, "gzip")
    // Gzip payloads start with the magic bytes 0x1f 0x8b.
    assert_true(body.val.length() >= 2)
    assert_eq(body.val[0], b'\x1f')
    assert_eq(body.val[1], b'\x8b')
  }
}
