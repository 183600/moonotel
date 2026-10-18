// Regression tests: spans buffered by a `BatchSpanProcessor` must still reach
// an async OTLP exporter when the task group exits, even though the exporter's
// background sender is cancelled before the group defers run.

///|
async test "batch processor spans reach the async exporter on group exit" {
  @async.with_task_group() <| outer => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let received : Ref[Int32] = Ref(0)
    outer.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        let _ = body.read_all()
        received.val = received.val + 1
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    @async.with_task_group() <| group => {
      let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(config, group)
      let processor = @sdk.BatchSpanProcessor::new(
        exporter,
        max_export_batch_size=1000000,
        flush_interval_millis=600000,
      )
      @async_runtime.spawn_flush_loop(group, processor)
      let provider = @sdk.TracerProviderSdk::new(service_name="batch-exit").with_span_processor(
        processor,
      )
      let tracer = provider.get_tracer("batch-exit")
      let span = tracer.start_root_span("buffered")
      span.end()
      // Exit immediately: the batch processor defer must run before the
      // exporter finishes draining.
    }
    assert_true(received.val >= 1)
  }
}
