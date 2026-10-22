// Tests for the native async runtime helpers: the queue-backed OTLP exporter,
// the batch flush loop, context-aware spawning and the one-call setup.

///|
struct CollectingExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

///|
pub impl @sdk.SpanExporter for CollectingExporter with fn export_spans(
  self,
  spans,
) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for CollectingExporter with fn shutdown(self) {
  let _ = self
}

///|
async test "otlp async exporter delivers spans while the group runs" {
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
      let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(
        config, group,
      )
      let provider = @sdk.TracerProviderSdk::new(service_name="async-runtime").with_span_processor(
        @sdk.SimpleSpanProcessor::new(exporter),
      )
      let tracer = provider.get_tracer("async-runtime")
      let span = tracer.start_root_span("delivered")
      span.end()
      @async.sleep(200)
      assert_true(received.val >= 1)
      assert_false(exporter.is_shutdown())
      assert_eq(exporter.export_failures(), 0)
    }
  }
}

///|
async test "otlp async exporter drains pending spans when the group exits" {
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
      let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(
        config, group,
      )
      let provider = @sdk.TracerProviderSdk::new(service_name="async-runtime").with_span_processor(
        @sdk.SimpleSpanProcessor::new(exporter),
      )
      let tracer = provider.get_tracer("async-runtime")
      let span = tracer.start_root_span("pending")
      span.end()
      // Exit immediately: the pending span must still be drained.
    }
    assert_true(received.val >= 1)
  }
}

///|
async test "shutdown closes the queue and stops accepting spans" {
  @async.with_task_group() <| group => {
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:1")
    let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(config, group)
    assert_false(exporter.is_shutdown())
    exporter.shutdown()
    assert_true(exporter.is_shutdown())
    let result = exporter.export_spans([])
    assert_false(result.is_success())
    assert_eq(exporter.dropped_batches(), 0)
  }
}

///|
async test "queue overflow evicts real batches and ignores empty batches" {
  @async.with_task_group() <| group => {
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:1",
      timeout_millis=100,
      max_retries=0,
    )
    let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(
      config,
      group,
      max_queue_size=1,
    )
    let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(exporter)
    let provider = @sdk.TracerProviderSdk::new(
      service_name="queue-overflow",
    ).with_span_processor(processor)
    let tracer = provider.get_tracer("queue-overflow")
    // An empty export is a successful no-op and never takes the only slot.
    assert_true(exporter.export_spans([]).is_success())
    assert_eq(exporter.dropped_batches(), 0)
    tracer.start_root_span("one").end()
    assert_eq(exporter.dropped_batches(), 0)
    // The queue holds one batch, so the next two exports each evict one.
    tracer.start_root_span("two").end()
    tracer.start_root_span("three").end()
    assert_eq(exporter.dropped_batches(), 2)
    // An empty batch must not evict the real batch still queued.
    assert_true(exporter.export_spans([]).is_success())
    assert_eq(exporter.dropped_batches(), 2)
  }
}

///|
async test "otlp async exporter counts failed requests" {
  @async.with_task_group() <| group => {
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:1",
      timeout_millis=2000,
      max_retries=0,
    )
    let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(config, group)
    let provider = @sdk.TracerProviderSdk::new(service_name="async-failures").with_span_processor(
      @sdk.SimpleSpanProcessor::new(exporter),
    )
    let tracer = provider.get_tracer("async-failures")
    assert_eq(exporter.export_failures(), 0)
    tracer.start_root_span("lost").end()
    // The failed connection attempt may take a moment to surface; poll until
    // it is counted instead of relying on a fixed sleep.
    let mut waited = 0
    while waited < 3000 && exporter.export_failures() == 0 {
      @async.sleep(25)
      waited = waited + 25
    }
    assert_true(exporter.export_failures() >= 1)
    assert_eq(exporter.dropped_batches(), 0)
  }
}

///|
async test "spawn_flush_loop exports spans within the interval" {
  let exporter : CollectingExporter = { spans: Ref([]), }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=100,
    flush_interval_millis=50,
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="flush-loop").with_span_processor(
    processor,
  )
  let tracer = provider.get_tracer("flush-loop")
  @async.with_task_group() <| group => {
    @async_runtime.spawn_flush_loop(group, processor)
    let span = tracer.start_root_span("queued")
    span.end()
    @async.sleep(300)
    assert_eq(exporter.spans.val.length(), 1)
  }
}

///|
async test "spawn_flush_loop flushes queued spans when the group exits" {
  let exporter : CollectingExporter = { spans: Ref([]), }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=1000000,
    flush_interval_millis=600000,
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="flush-loop-exit").with_span_processor(
    processor,
  )
  let tracer = provider.get_tracer("flush-loop-exit")
  @async.with_task_group() <| group => {
    @async_runtime.spawn_flush_loop(group, processor)
    let span = tracer.start_root_span("flushed-on-exit")
    span.end()
  }
  assert_eq(exporter.spans.val.length(), 1)
  assert_eq(exporter.spans.val[0].name, "flushed-on-exit")
}

///|
async test "spawn_bg carries the current context into the child" {
  let baggage : Ref[String?] = Ref(None)
  let has_span : Ref[Bool] = Ref(false)
  @async.with_task_group() <| group => {
    let span_context = @api.span_context(
      Array::make(16, 5),
      Array::make(8, 6),
      @api.TRACE_FLAGS_SAMPLED,
    )
    let previous = @context.attach(
      @context.Context::root()
      .with_value("user.id", "ada")
      .with_span(span_context),
    )
    @async_runtime.spawn_bg(group) <| () => {
      baggage.val = @context.current_context().value("user.id")
      has_span.val = match @context.current_span_context() {
        Some(sc) => sc.is_valid()
        None => false
      }
    }
    @context.detach(previous)
  }
  assert_eq(baggage.val, Some("ada"))
  assert_true(has_span.val)
}

///|
async test "spawn_bg accepts an explicit context" {
  let seen : Ref[String?] = Ref(None)
  @async.with_task_group() <| group => {
    @async_runtime.spawn_bg(
      group,
      () => seen.val = @context.current_context().value("tenant"),
      context=@context.Context::root().with_value("tenant", "acme"),
    )
  }
  assert_eq(seen.val, Some("acme"))
}

///|
async test "setup builds a global provider that exports spans" {
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
    @async.with_task_group() <| group => {
      let provider = @async_runtime.setup(
        group,
        service_name="async-setup",
        endpoint="http://127.0.0.1:\{port}",
      )
      assert_eq(
        provider.resource().get(@sdk.SERVICE_NAME),
        Some(@sdk.StringValue("async-setup")),
      )
      let tracer = provider.get_tracer("async-setup")
      let span = tracer.start_root_span("setup-span")
      span.end()
      @async.sleep(200)
    }
    assert_true(received.val >= 1)
  }
  @sdk.shutdown_global_tracer_provider()
}

///|
async test "setup accepts a prebuilt resource" {
  @async.with_task_group() <| group => {
    let resource = @sdk.Resource::new(
      attributes=Map([
        (@sdk.SERVICE_NAME, @sdk.StringValue("async-resource")),
        ("deployment.environment", @sdk.StringValue("staging")),
      ]),
    )
    let provider = @async_runtime.setup(
      group,
      resource~,
      resource_attributes=Map([
        ("deployment.environment", @sdk.StringValue("production")),
      ]),
    )
    assert_eq(
      provider.resource().get(@sdk.SERVICE_NAME),
      Some(@sdk.StringValue("async-resource")),
    )
    assert_eq(
      provider.resource().get("deployment.environment"),
      Some(@sdk.StringValue("production")),
    )
  }
  @sdk.shutdown_global_tracer_provider()
}
