// Tests for `BatchSpanProcessor::from_env` (OTEL_BSP_* configuration) and for
// the dropped-span accounting when the queue overflows.

///|
fn clear_bsp_env() -> Unit {
  @env.unset_env_var("OTEL_BSP_MAX_QUEUE_SIZE")
  @env.unset_env_var("OTEL_BSP_MAX_EXPORT_BATCH_SIZE")
  @env.unset_env_var("OTEL_BSP_SCHEDULE_DELAY")
}

///|
test "batch_processor_from_env_defaults" {
  clear_bsp_env()
  let exporter : ProbeExporter = { names: [], }
  let processor = @sdk.BatchSpanProcessor::from_env(exporter)
  assert_eq(processor.flush_interval_millis(), 5000)
  assert_eq(processor.dropped_spans(), 0UL)
  processor.on_end(probe_span("s0"))
  assert_eq(processor.queue_size(), 1)
}

///|
test "batch_processor_from_env_reads_configuration" {
  clear_bsp_env()
  @env.set_env_var("OTEL_BSP_MAX_QUEUE_SIZE", "3")
  @env.set_env_var("OTEL_BSP_MAX_EXPORT_BATCH_SIZE", "10")
  @env.set_env_var("OTEL_BSP_SCHEDULE_DELAY", "250")
  let exporter : ProbeExporter = { names: [], }
  let processor = @sdk.BatchSpanProcessor::from_env(exporter)
  clear_bsp_env()
  assert_eq(processor.flush_interval_millis(), 250)
  // The export batch size is capped at the queue size (3).
  processor.on_end(probe_span("s0"))
  processor.on_end(probe_span("s1"))
  assert_eq(exporter.names.length(), 0)
  processor.on_end(probe_span("s2"))
  assert_eq(exporter.names.length(), 3)
  assert_eq(processor.queue_size(), 0)
}

///|
test "batch_processor_from_env_ignores_malformed_values" {
  clear_bsp_env()
  @env.set_env_var("OTEL_BSP_MAX_EXPORT_BATCH_SIZE", "not-a-number")
  @env.set_env_var("OTEL_BSP_SCHEDULE_DELAY", "  ")
  let exporter : ProbeExporter = { names: [], }
  let processor = @sdk.BatchSpanProcessor::from_env(exporter)
  clear_bsp_env()
  assert_eq(processor.flush_interval_millis(), 5000)
}

///|
test "batch_processor_from_env_ignores_non_positive_values" {
  clear_bsp_env()
  @env.set_env_var("OTEL_BSP_MAX_QUEUE_SIZE", "-4")
  @env.set_env_var("OTEL_BSP_MAX_EXPORT_BATCH_SIZE", "0")
  @env.set_env_var("OTEL_BSP_SCHEDULE_DELAY", "-1")
  let exporter : ProbeExporter = { names: [], }
  let processor = @sdk.BatchSpanProcessor::from_env(exporter)
  clear_bsp_env()
  assert_eq(processor.flush_interval_millis(), 5000)
  for index = 0; index < 512; index = index + 1 {
    processor.on_end(probe_span("s\{index}"))
  }
  assert_eq(exporter.names.length(), 512)
  assert_eq(processor.dropped_spans(), 0UL)
}

///|
test "batch_processor_caps_batch_size_before_dropping" {
  let exporter : ProbeExporter = { names: [], }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=2,
    max_export_batch_size=100,
  )
  processor.on_end(probe_span("s0"))
  processor.on_end(probe_span("s1"))
  assert_eq(processor.dropped_spans(), 0UL)
  assert_true(probe_names_equal(exporter.names, ["s0", "s1"]))
  processor.on_end(probe_span("s2"))
  processor.on_end(probe_span("s3"))
  assert_eq(processor.dropped_spans(), 0UL)
  processor.force_flush()
  assert_true(probe_names_equal(exporter.names, ["s0", "s1", "s2", "s3"]))
}
