// Tests for `BatchConfig` and `BatchSpanProcessor::with_config`.

///|
struct ProbeExporter {
  names : Array[String]
}

///|
pub impl @sdk.SpanExporter for ProbeExporter with fn export_spans(self, spans) {
  for data in spans {
    self.names.push(data.name)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for ProbeExporter with fn shutdown(self) {
  let _ = self
}

///|
fn probe_span(name : String) -> @sdk.SpanData {
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
fn probe_names_equal(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
test "batch_config_defaults" {
  let config = @sdk.BatchConfig::default()
  assert_eq(config.max_queue_size, 2048)
  assert_eq(config.max_export_batch_size, 512)
  assert_eq(config.flush_interval_millis, 5000)
}

///|
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

///|
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

///|
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

///|
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

///|
test "batch_config_caps_export_batch_at_queue_size" {
  let config = @sdk.BatchConfig::new(
    max_queue_size=2,
    max_export_batch_size=10,
    flush_interval_millis=0,
  )
  assert_eq(config.max_queue_size, 2)
  assert_eq(config.max_export_batch_size, 2)
  let exporter : ProbeExporter = { names: [], }
  let processor = @sdk.BatchSpanProcessor::with_config(exporter, config)
  processor.on_end(probe_span("s0"))
  assert_eq(processor.queue_size(), 1)
  assert_eq(exporter.names.length(), 0)
  // The effective batch size is the queue size, so the second span exports
  // immediately instead of the queue overflowing and dropping the first.
  processor.on_end(probe_span("s1"))
  assert_eq(processor.queue_size(), 0)
  assert_eq(processor.dropped_spans(), 0UL)
  assert_true(probe_names_equal(exporter.names, ["s0", "s1"]))
}

///|
test "batch_processor_new_caps_export_batch_at_queue_size" {
  let exporter : ProbeExporter = { names: [], }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=2,
    max_export_batch_size=8,
    flush_interval_millis=0,
  )
  processor.on_end(probe_span("s0"))
  processor.on_end(probe_span("s1"))
  assert_eq(processor.queue_size(), 0)
  assert_eq(processor.dropped_spans(), 0UL)
  assert_true(probe_names_equal(exporter.names, ["s0", "s1"]))
}

///|
test "batch_processor_with_config_uses_every_field" {
  let exporter : ProbeExporter = { names: [], }
  let config = @sdk.BatchConfig::new(
    max_queue_size=1,
    max_export_batch_size=2,
    flush_interval_millis=0,
  )
  // A batch larger than the queue is capped at the queue size, as required by
  // the OpenTelemetry SDK specification.
  assert_eq(config.max_export_batch_size, 1)
  let processor = @sdk.BatchSpanProcessor::with_config(exporter, config)
  assert_eq(processor.flush_interval_millis(), 0)
  processor.on_end(probe_span("s0"))
  // The effective export batch size is 1, so the span is exported right away.
  assert_eq(processor.queue_size(), 0)
  assert_eq(processor.dropped_spans(), 0UL)
  assert_true(probe_names_equal(exporter.names, ["s0"]))
  processor.on_end(probe_span("s1"))
  processor.force_flush()
  assert_eq(processor.queue_size(), 0)
  assert_true(probe_names_equal(exporter.names, ["s0", "s1"]))
}

///|
test "batch_config_from_env_accepts_zero_schedule_delay" {
  clear_bsp_env()
  @env.set_env_var("OTEL_BSP_SCHEDULE_DELAY", "0")
  let config = @sdk.BatchConfig::from_env()
  clear_bsp_env()
  assert_eq(config.flush_interval_millis, 0)
}

///|
test "batch_config_from_env_rejects_non_decimal_numbers" {
  clear_bsp_env()
  @env.set_env_var("OTEL_BSP_MAX_QUEUE_SIZE", "0x10")
  @env.set_env_var("OTEL_BSP_MAX_EXPORT_BATCH_SIZE", "1_0")
  @env.set_env_var("OTEL_BSP_SCHEDULE_DELAY", "0b101")
  let config = @sdk.BatchConfig::from_env()
  clear_bsp_env()
  assert_eq(config.max_queue_size, 2048)
  assert_eq(config.max_export_batch_size, 512)
  assert_eq(config.flush_interval_millis, 5000)
}
