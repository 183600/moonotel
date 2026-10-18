// Tests for the awaited, context-propagating `spawn` helper and for
// `OTEL_TRACES_EXPORTER=none` in the one-call setup.

///|
async test "spawn carries the current context into the child" {
  let seen : Ref[String?] = Ref(None)
  @async.with_task_group() <| group => {
    let previous = @context.attach(
      @context.Context::root().with_value("user.id", "grace"),
    )
    let task = @async_runtime.spawn(group, () => {
      seen.val = @context.current_context().value("user.id")
    })
    task.wait()
    @context.detach(previous)
  }
  assert_eq(seen.val, Some("grace"))
}

///|
async test "spawn returns the task result" {
  @async.with_task_group() <| group => {
    let task = @async_runtime.spawn(group, () => 21 * 2)
    assert_eq(task.wait(), 42)
  }
}

///|
async test "spawn carries the current span context" {
  let seen : Ref[Bool] = Ref(false)
  @async.with_task_group() <| group => {
    let previous = @context.attach(
      @context.Context::root().with_span(
        @api.span_context(
          Array::make(16, 9),
          Array::make(8, 10),
          @api.TRACE_FLAGS_SAMPLED,
        ),
      ),
    )
    let task = @async_runtime.spawn(group, () => {
      seen.val = match @context.current_span_context() {
        Some(sc) => sc.is_valid()
        None => false
      }
    })
    task.wait()
    @context.detach(previous)
  }
  assert_true(seen.val)
}

///|
async test "spawn accepts an explicit context" {
  let seen : Ref[String?] = Ref(None)
  @async.with_task_group() <| group => {
    let task = @async_runtime.spawn(
      group,
      () => seen.val = @context.current_context().value("tenant"),
      context=@context.Context::root().with_value("tenant", "acme"),
    )
    task.wait()
  }
  assert_eq(seen.val, Some("acme"))
}

///|
async test "setup_with_traces_exporter_none_installs_a_provider_without_exporter" {
  @env.set_env_var("OTEL_TRACES_EXPORTER", "none")
  @async.with_task_group() <| group => {
    let provider = @async_runtime.setup(group, service_name="no-exporter")
    assert_eq(
      provider.resource().get(@sdk.SERVICE_NAME),
      Some(@sdk.StringValue("no-exporter")),
    )
    let tracer = provider.get_tracer("no-exporter")
    let span = tracer.start_root_span("recorded")
    assert_true(span.is_recording())
    span.end()
    provider.force_flush()
  }
  @env.unset_env_var("OTEL_TRACES_EXPORTER")
  @sdk.shutdown_global_tracer_provider()
}
