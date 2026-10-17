///|
test "zz_myprobe_env_wb" (b : @bench.T) {
  b.bench(fn() {
    let _ = @env.get_env_vars()
  })
  b.bench(fn() {
    let vars = @env.get_env_vars()
    let _ = vars.get("OTEL_TRACES_SAMPLER")
    let _ = vars.get("OTEL_TRACES_SAMPLER_ARG")
    let _ = vars.get("OTEL_SERVICE_NAME")
    let _ = vars.get("OTEL_RESOURCE_ATTRIBUTES")
    let _ = vars.get("OTEL_SDK_DISABLED")
  })
  b.bench(fn() {
    let _ = @env.get_env_var("OTEL_BSP_MAX_QUEUE_SIZE")
    let _ = @env.get_env_var("OTEL_BSP_MAX_EXPORT_BATCH_SIZE")
    let _ = @env.get_env_var("OTEL_BSP_SCHEDULE_DELAY")
  })
}
