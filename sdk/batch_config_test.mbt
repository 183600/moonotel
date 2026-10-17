// Tests for `BatchConfig` and `BatchSpanProcessor::with_config`.

test "batch_config_defaults" {
  let config = @sdk.BatchConfig::default()
  assert_eq(config.max_queue_size, 2048)
  assert_eq(config.max_export_batch_size, 512)
  assert_eq(config.flush_interval_millis, 5000)
}

test "batch_config_new_clamps_out_of_range_values" {
  let config = @sdk.BatchConfig::new(
    max_queue_size=0,
    max_export_batch_size=-3,
    flush_interval_millis=-1,
  )
  assert_eq(config.max_queue_size, 1)
  assert_eq(config.max_export_batch_size, 1)
  assert_eq(config.flush_interval_millis, 0)
}

test "batch_config_new_honors_explicit_values" {
  let config = @sdk.BatchConfig::new(
    max_queue_size=16,
    max_export_batch_size=4,
    flush_interval_millis=250,
  )
  assert_eq(config.max_queue_size, 16)
  assert_eq(config.max_export_batch_size, 4)
  assert_eq(config.flush_interval_millis, 250)
}

test "batch_config_from_env_reads_configuration" {
  clear_bsp_env()
  @env.set_env_var("OTEL_BSP_MAX_QUEUE_SIZE", "3")
  @env.set_env_var("OTEL_BSP_MAX_EXPORT_BATCH_SIZE", "10")
  @env.set_env_var("OTEL_BSP_SCHEDULE_DELAY", "250")
  let config = @sdk.BatchConfig::from_env()
  clear_bsp_env()
  assert_eq(config.max_queue_size, 3)
  // The export batch size is capped at the queue size.
  assert_eq(config.max_export_batch_size, 3)
  assert_eq(config.flush_interval_millis, 250)
}

test "batch_config_from_env_falls_back_on_malformed_values" {
  clear_bsp_env()
  @env.set_env_var("OTEL_BSP_MAX_QUEUE_SIZE", "not-a-number")
  @env.set_env_var("OTEL_BSP_MAX_EXPORT_BATCH_SIZE", "-2")
  @env.set_env_var("OTEL_BSP_SCHEDULE_DELAY", "  ")
  let config = @sdk.BatchConfig::from_env()
  clear_bsp_env()
  assert_eq(config.max_queue_size, 2048)
  assert_eq(config.max_export_batch_size, 512)
  assert_eq(config.flush_interval_millis, 5000)
}

test "batch_processor_with_config_uses_every_field" {
  let exporter : ProbeExporter = { names: [] }
  let config = @sdk.BatchConfig::new(
    max_queue_size=1,
    max_export_batch_size=2,
    flush_interval_millis=0,
  )
  let processor = @sdk.BatchSpanProcessor::with_config(exporter, config)
  assert_eq(processor.flush_interval_millis(), 0)
  processor.on_end(probe_span("s0"))
  // The export batch size (2) has not been reached, so the span stays queued.
  assert_eq(processor.queue_size(), 1)
  assert_eq(exporter.names.length(), 0)
  // The queue size (1) is exceeded, so the oldest span is dropped.
  processor.on_end(probe_span("s1"))
  assert_eq(processor.dropped_spans(), 1UL)
  assert_eq(processor.queue_size(), 1)
  processor.on_end(probe_span("s2"))
  assert_eq(processor.dropped_spans(), 2UL)
  processor.force_flush()
  assert_eq(processor.queue_size(), 0)
  assert_true(probe_names_equal(exporter.names, ["s2"]))
}
