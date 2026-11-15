// Regression test: `flush` must only wait for batches accepted before it was
// called. A producer that keeps ending spans must not keep it busy until the
// producer stops.

///|
async test "flush returns while spans keep arriving" {
  @async.with_task_group() <| outer => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let received : Ref[Int32] = Ref(0)
    outer.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        let _ = body.read_all()
        @async.sleep(100)
        received.val = received.val + 1
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    @async.with_task_group() <| group => {
      let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(
        config, group,
      )
      let provider = @sdk.TracerProviderSdk::new(
        service_name="async-flush-under-load",
      ).with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
      let tracer = provider.get_tracer("async-flush-under-load")
      group.spawn_bg(no_wait=true) <| () => {
        let producer_started = @env.now()
        while @env.now() - producer_started < 3000UL {
          tracer.start_root_span("load").end()
          @async.sleep(10)
        }
      }
      // Let some batches accumulate, then flush while the producer is still
      // running. The pre-flush batches fit in one request, so flush should
      // return after that request instead of chasing newly arriving spans.
      @async.sleep(200)
      let flush_started = @env.now()
      exporter.flush()
      let elapsed = @env.now() - flush_started
      assert_true(elapsed < 2000UL)
      assert_true(received.val >= 1)
      assert_eq(exporter.export_failures(), 0)
    }
  }
}
