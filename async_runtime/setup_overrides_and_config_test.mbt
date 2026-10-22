// Native async setup honors the explicit sampler/span-limit overrides, the
// exporter exposes its configuration, and a non-positive flush interval keeps
// timed flushes disabled while still flushing on group exit.

///|
async test "async_setup_applies_sampler_and_span_limit_overrides" {
  @async.with_task_group() <| group => {
    let provider = @async_runtime.setup(
      group,
      service_name="async-overrides",
      exporters=["none"],
      sampler=@sdk.Sampler::always_off(),
      span_limits=@sdk.SpanLimits::new(attribute_count_limit=3),
      install_global=false,
    )
    assert_eq(provider.sampler().description(), "AlwaysOffSampler")
    assert_eq(provider.span_limits().attribute_count_limit(), 3)
    let span = provider.get_tracer("async-overrides").start_root_span("dropped")
    assert_false(span.is_recording())
  }
}

///|
async test "async_exporter_exposes_its_configuration" {
  @async.with_task_group() <| group => {
    let config = @otlp.OtlpHttpConfig::new(
      endpoint="http://127.0.0.1:4318/base",
      compression="gzip",
      protocol="http/json",
      max_retries=1,
    )
    let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(config, group)
    let observed = exporter.config()
    assert_eq(observed.endpoint, "http://127.0.0.1:4318/base")
    assert_eq(observed.traces_url(), "http://127.0.0.1:4318/base/v1/traces")
    assert_eq(observed.compression, "gzip")
    assert_eq(observed.protocol, "http/json")
    assert_eq(observed.max_retries, 1)
  }
}

///|
async test "spawn_flush_loop_with_zero_interval_flushes_on_group_exit" {
  let exporter : CollectingExporter = { spans: Ref([]), }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=100,
    flush_interval_millis=600000,
  )
  let provider = @sdk.TracerProviderSdk::new(
    service_name="zero-interval",
  ).with_span_processor(processor)
  let tracer = provider.get_tracer("zero-interval")
  @async.with_task_group() <| group => {
    // Explicit zero disables the timed loop; the group defer still flushes.
    @async_runtime.spawn_flush_loop(group, processor, interval_millis=0)
    tracer.start_root_span("queued").end()
    @async.sleep(50)
    assert_eq(exporter.spans.val.length(), 0)
  }
  assert_eq(exporter.spans.val.length(), 1)
}

///|
async test "async_span_exporter_sends_with_a_zero_timeout" {
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
      let config = @otlp.OtlpHttpConfig::new(
        endpoint="http://127.0.0.1:\{port}",
        timeout_millis=0,
        max_retries=0,
      )
      let exporter = @async_runtime.OtlpHttpAsyncSpanExporter::new(config, group)
      let provider = @sdk.TracerProviderSdk::new(
        service_name="zero-timeout",
      ).with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
      provider.get_tracer("zero-timeout").start_root_span("sent").end()
      let mut waited = 0
      while waited < 3000 && received.val == 0 {
        @async.sleep(25)
        waited = waited + 25
      }
      assert_true(received.val >= 1)
    }
  }
}
