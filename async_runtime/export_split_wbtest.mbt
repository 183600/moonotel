// White-box regression test for splitting oversized queued batches in
// `OtlpHttpAsyncSpanExporter::export_available`: a batch that is split while
// filling a request must be re-split when its remainder exceeds the
// per-request limit, so no OTLP request ever carries more than
// `MAX_EXPORT_SPANS` spans.

///|
fn split_probe_span(name : String) -> @sdk.SpanData {
  {
    name,
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map([], capacity=1),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(Map([], capacity=1)),
    scope_name: "scope",
    scope_version: "",
  }
}

///|
fn count_encoded_spans(body : String) -> Int32 {
  let needle = "\"traceId\""
  let mut count = 0
  let mut rest = body[:]
  while true {
    match rest.find(needle) {
      Some(at) => {
        count = count + 1
        rest = rest[at + needle.length():]
      }
      None => break
    }
  }
  count
}

///|
async test "oversized queued batch is re-split after a partial fill" {
  @async.with_task_group() <| outer => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let spans_per_request : Array[Int32] = []
    outer.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        spans_per_request.push(count_encoded_spans(body.read_all().text()))
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:\{port}",
      protocol=@otlp.OTLP_HTTP_JSON_PROTOCOL,
    )
    let queue : @aqueue.Queue[Array[@sdk.SpanData]] = @aqueue.Queue(
      kind=@aqueue.DiscardOldest(4),
    )
    let exporter : OtlpHttpAsyncSpanExporter = {
      exporter: @otlp_async.OtlpHttpAsyncExporter::new(config),
      queue,
      shutdown_called: false,
      dropped: 0,
      failures: 0,
      active_sends: 0,
      send_finished: @cond_var.Cond(),
    }
    // The first batch takes one slot, so 511 spans of the queued 1025 fit in
    // the same request and 514 are left over: the remainder exceeds the
    // per-request limit and must be split again.
    let queued : Array[@sdk.SpanData] = Array::make(
      1025,
      split_probe_span("queued"),
    )
    let _ = queue.try_put(queued) catch { _ => false }
    exporter.export_available([split_probe_span("first")])
    assert_eq(spans_per_request.length(), 3)
    assert_eq(spans_per_request[0], 512)
    assert_eq(spans_per_request[1], 512)
    assert_eq(spans_per_request[2], 2)
  }
}
