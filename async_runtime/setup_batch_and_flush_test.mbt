// Tests for batch-processor selection in the native async setup and for the
// explicit async exporter flush.

///|
async fn start_counting_server(
  outer : @async.TaskGroup[Unit],
  marker : String,
) -> (Int32, Ref[Int32]) {
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  let port = server.addr.port()
  let received : Ref[Int32] = Ref(0)
  outer.spawn_bg(no_wait=true) <| () => {
    server.run_forever() <| ((_request, body, conn) => {
      // Only count exports that belong to this test (matched by its unique
      // service name): `127.0.0.1:0` binds an ephemeral port that a concurrently
      // running test executable can reuse for a stray retry, and such a
      // foreign request must not fail the "still buffered" assertions below.
      let text = @utf8.decode_lossy(body.read_all().binary().exact_view())
      if text.contains(marker) {
        received.val = received.val + 1
      }
      conn.send_response(200, "OK")
    })
  }
  (port, received)
}

///|
async test "async setup with a batch config flushes buffered spans on exit" {
  @async.with_task_group() <| outer => {
    let (port, received) = start_counting_server(outer, "async-batch-config")
    @async.with_task_group() <| group => {
      // `install_global=false` keeps this provider out of the process-wide slot:
      // async tests in one executable interleave, and another test's
      // `shutdown_global_tracer_provider()` would otherwise force-flush (and
      // export) this provider's buffered spans mid-test.
      let provider = @async_runtime.setup(
        group,
        service_name="async-batch-config",
        endpoint="http://127.0.0.1:\{port}",
        batch=@sdk.BatchConfig::new(
          max_export_batch_size=1000000,
          flush_interval_millis=600000,
        ),
        install_global=false,
      )
      let tracer = provider.get_tracer("async-batch-config")
      tracer.start_root_span("buffered").end()
      @async.sleep(50)
      assert_eq(received.val, 0)
    }
    assert_true(received.val >= 1)
  }
}

///|
async test "async setup with use_batch installs a batch processor" {
  @async.with_task_group() <| outer => {
    let (port, received) = start_counting_server(outer, "async-batch-option")
    @async.with_task_group() <| group => {
      let provider = @async_runtime.setup(
        group,
        service_name="async-batch-option",
        endpoint="http://127.0.0.1:\{port}",
        use_batch=true,
      )
      let tracer = provider.get_tracer("async-batch-option")
      tracer.start_root_span("buffered").end()
    }
    assert_true(received.val >= 1)
  }
  @sdk.shutdown_global_tracer_provider()
}

///|
async test "async setup without batching exports spans while the group runs" {
  @async.with_task_group() <| outer => {
    let (port, received) = start_counting_server(outer, "async-simple")
    @async.with_task_group() <| group => {
      let provider = @async_runtime.setup(
        group,
        service_name="async-simple",
        endpoint="http://127.0.0.1:\{port}",
      )
      let tracer = provider.get_tracer("async-simple")
      tracer.start_root_span("immediate").end()
      let mut waited = 0
      while waited < 2000 && received.val == 0 {
        @async.sleep(25)
        waited = waited + 25
      }
      assert_true(received.val >= 1)
    }
  }
  @sdk.shutdown_global_tracer_provider()
}

///|
async test "async exporter flush waits for queued spans to be sent" {
  @async.with_task_group() <| outer => {
    let (port, received) = start_counting_server(outer, "async-flush")
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    @async.with_task_group() <| group => {
      let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(
        config, group,
      )
      let provider = @sdk.TracerProviderSdk::new(
        service_name="async-flush",
      ).with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
      let tracer = provider.get_tracer("async-flush")
      tracer.start_root_span("flushed").end()
      exporter.flush()
      assert_true(received.val >= 1)
      assert_eq(exporter.export_failures(), 0)
    }
  }
}

///|
async test "async exporter flush waits for a batch handed to the idle sender" {
  @async.with_task_group() <| outer => {
    let (port, received) = start_counting_server(outer, "async-flush-handoff")
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    @async.with_task_group() <| group => {
      let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(
        config, group,
      )
      // Let the background sender block in `queue.get()`, so the next enqueue
      // is handed directly to it and never enters the queue buffer.
      @async.sleep(50)
      let provider = @sdk.TracerProviderSdk::new(
        service_name="async-flush-handoff",
      ).with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
      let tracer = provider.get_tracer("async-flush-handoff")
      tracer.start_root_span("handoff").end()
      exporter.flush()
      assert_true(received.val >= 1)
      assert_eq(exporter.export_failures(), 0)
    }
  }
}

///|
async test "async exporter flush waits for an in-flight request" {
  @async.with_task_group() <| outer => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let started : Ref[Bool] = Ref(false)
    let completed : Ref[Bool] = Ref(false)
    outer.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, body, conn) => {
        let _ = body.read_all()
        started.val = true
        @async.sleep(300)
        completed.val = true
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    @async.with_task_group() <| group => {
      let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(
        config, group,
      )
      let provider = @sdk.TracerProviderSdk::new(
        service_name="async-flush-in-flight",
      ).with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
      let tracer = provider.get_tracer("async-flush-in-flight")
      tracer.start_root_span("in-flight").end()
      let mut waited = 0
      while !started.val && waited < 2000 {
        @async.sleep(10)
        waited = waited + 10
      }
      assert_true(started.val)
      assert_false(completed.val)
      exporter.flush()
      assert_true(completed.val)
      assert_eq(exporter.export_failures(), 0)
    }
  }
}
