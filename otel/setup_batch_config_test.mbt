// `setup` applies an explicit `BatchConfig` and prefers it over `use_batch`.

test "setup_with_batch_config_exports_on_flush" {
  @otel.shutdown_global_tracer_provider()
  let capture = capturing_transport()
  let provider = @otel.setup(
    service_name="batch-config-facade",
    endpoint="http://collector:4318",
    transport=capture.send(),
    batch=@sdk.BatchConfig::new(
      max_queue_size=8,
      max_export_batch_size=8,
      flush_interval_millis=0,
    ),
  )
  let tracer = @otel.global_tracer("batch-config-scope")
  let span = tracer.start_root_span("queued")
  span.end()
  // The custom batch size keeps the span queued until an explicit flush.
  assert_eq(capture.urls.length(), 0)
  provider.force_flush()
  assert_eq(capture.urls.length(), 1)
  assert_eq(capture.urls[0], "http://collector:4318/v1/traces")
  @otel.shutdown_global_tracer_provider()
}

test "explicit_batch_config_overrides_use_batch_false" {
  @otel.shutdown_global_tracer_provider()
  let capture = capturing_transport()
  let provider = @otel.setup(
    service_name="batch-config-facade",
    endpoint="http://collector:4318",
    transport=capture.send(),
    use_batch=false,
    batch=@sdk.BatchConfig::new(
      max_export_batch_size=4,
      flush_interval_millis=0,
    ),
  )
  let tracer = @otel.global_tracer("batch-config-scope")
  let span = tracer.start_root_span("still-batched")
  span.end()
  // A simple processor would have exported immediately; the batch processor
  // keeps the span queued until shutdown.
  assert_eq(capture.urls.length(), 0)
  provider.shutdown()
  assert_eq(capture.urls.length(), 1)
  @otel.shutdown_global_tracer_provider()
}
