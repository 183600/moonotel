// White-box regression test: coalescing queued batches must not append spans
// to the caller's `first` array, which may still be observed by user code.

///|
async test "export_available keeps the caller's first batch unchanged" {
  @async.with_task_group() <| outer => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    outer.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        let _ = body.read_all()
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
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
    let first = Array::make(1, split_probe_span("first"))
    let queued = Array::make(1, split_probe_span("queued"))
    let _ = queue.try_put(queued) catch { _ => false }
    exporter.export_available(first)
    assert_eq(first.length(), 1)
    assert_eq(first[0].name, "first")
  }
}
