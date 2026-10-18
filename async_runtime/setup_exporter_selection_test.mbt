// Exporter selection in the native async setup, driven by explicit lists so
// the tests do not depend on (or mutate) process-global environment state.

///|
async test "async_setup_with_console_only_skips_the_otlp_exporter" {
  @async.with_task_group() <| group => {
    let provider = @async_runtime.setup(group, service_name="console-async", exporters=[
      "console",
    ])
    assert_eq(provider.processor_count(), 1)
    let tracer = provider.get_tracer("console-async")
    let span = tracer.start_root_span("printed")
    span.end()
    provider.force_flush()
  }
  @sdk.shutdown_global_tracer_provider()
}

///|
async test "async_setup_with_console_and_otlp_installs_both_processors" {
  @async.with_task_group() <| group => {
    let provider = @async_runtime.setup(
      group,
      service_name="console-otlp-async",
      exporters=["console", "otlp"],
    )
    assert_eq(provider.processor_count(), 2)
  }
  @sdk.shutdown_global_tracer_provider()
}

///|
async test "async_setup_with_none_exporter_list_installs_nothing" {
  @async.with_task_group() <| group => {
    let provider = @async_runtime.setup(group, service_name="none-async", exporters=[
      "none",
    ])
    assert_eq(provider.processor_count(), 0)
  }
  @sdk.shutdown_global_tracer_provider()
}
