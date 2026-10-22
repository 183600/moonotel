// Environment integer parsing must reject values outside the `Int32` range and
// fall back to the documented defaults instead of wrapping around.

///|
test "batch_config_rejects_values_above_the_int32_range" {
  clear_bsp_env()
  @env.set_env_var("OTEL_BSP_MAX_QUEUE_SIZE", "2147483648")
  @env.set_env_var("OTEL_BSP_MAX_EXPORT_BATCH_SIZE", "99999999999999999999")
  @env.set_env_var("OTEL_BSP_SCHEDULE_DELAY", "2147483648")
  let config = @sdk.BatchConfig::from_env()
  clear_bsp_env()
  assert_eq(config.max_queue_size, 2048)
  assert_eq(config.max_export_batch_size, 512)
  assert_eq(config.flush_interval_millis, 5000)
}

///|
test "span_limits_reject_values_above_the_int32_range" {
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "2147483648")
  @env.set_env_var("OTEL_SPAN_EVENT_COUNT_LIMIT", "99999999999999999999")
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", "2147483648")
  let limits = @sdk.SpanLimits::from_env()
  @env.unset_env_var("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT")
  @env.unset_env_var("OTEL_SPAN_EVENT_COUNT_LIMIT")
  @env.unset_env_var("OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT")
  assert_eq(limits.attribute_count_limit(), 128)
  assert_eq(limits.event_count_limit(), 128)
  assert_eq(limits.attribute_value_length_limit(), -1)
}

///|
test "span_limits_accept_the_largest_int32_value" {
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "2147483647")
  @env.set_env_var("OTEL_SPAN_EVENT_COUNT_LIMIT", "2147483647")
  let limits = @sdk.SpanLimits::from_env()
  @env.unset_env_var("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT")
  @env.unset_env_var("OTEL_SPAN_EVENT_COUNT_LIMIT")
  assert_eq(limits.attribute_count_limit(), 2147483647)
  assert_eq(limits.event_count_limit(), 2147483647)
}
