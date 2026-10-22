// Native async runtime helpers for `183600/moonotel`: a background flush loop
// for batch span processors, context-aware task spawning and a one-call
// `setup` that exports spans over OTLP/HTTP from a background task.
//
// All helpers assume the caller runs inside `@async.with_task_group` (the
// standard structured-concurrency entry point of `moonbitlang/async`).

// Start a background flush loop for a batch processor: every
// `interval_millis` (the processor's own flush interval by default) the
// processor is ticked, and when the task group exits the processor is
// force-flushed.
//
// The loop is cancelled together with `group`, so no explicit shutdown is
// needed; spans still queued in the processor are flushed by the group defer
// as long as the exporter itself is synchronous.

///|
pub fn[G] spawn_flush_loop(
  group : @async.TaskGroup[G],
  processor : @sdk.BatchSpanProcessor,
  interval_millis? : Int32,
) -> Unit {
  let interval = match interval_millis {
    Some(value) => value
    None => processor.flush_interval_millis()
  }
  group.add_defer(() => processor.force_flush())
  if interval <= 0 {
    // Timed flushes are disabled for this processor; the defer above is the
    // only flush point.
    return
  }
  group.spawn_bg(no_wait=true) <| () => {
    while true {
      @async.sleep(interval)
      processor.tick()
    }
  }
}

// Spawn a background task that starts with `context` (the current context
// when omitted) installed as the ambient context, and restores the previous
// context when it finishes. Use this instead of `TaskGroup::spawn_bg` to
// carry the current span and baggage into tasks that outlive the caller.

///|
pub fn[G] spawn_bg(
  group : @async.TaskGroup[G],
  f : async () -> Unit,
  context? : @context.Context,
  no_wait? : Bool,
  allow_failure? : Bool,
) -> Unit {
  let carried = match context {
    Some(value) => value
    None => @context.current_context()
  }
  group.spawn_bg(
    () => {
      let previous = @context.attach(carried)
      defer @context.detach(previous)
      f()
    },
    no_wait?,
    allow_failure?,
  )
}

// Spawn a task that starts with `context` (the current context when omitted)
// installed as the ambient context, and restores the previous context when it
// finishes. Unlike `spawn_bg`, the returned task is joined through `group`
// and its result can be collected with `Task::wait`.

///|
pub fn[G, X] spawn(
  group : @async.TaskGroup[G],
  f : async () -> X,
  context? : @context.Context,
  no_wait? : Bool,
  allow_failure? : Bool,
) -> @async.Task[X] {
  let carried = match context {
    Some(value) => value
    None => @context.current_context()
  }
  group.spawn(
    () => {
      let previous = @context.attach(carried)
      defer @context.detach(previous)
      f()
    },
    no_wait?,
    allow_failure?,
  )
}

// One-call native setup: build a TracerProvider that exports over OTLP/HTTP
// through a background task in `group`, and install it as the process-wide
// provider. The exporters are selected by the `exporters` list when it is
// supplied and by the comma-separated `OTEL_TRACES_EXPORTER` environment
// variable otherwise: `otlp` (the default) installs the async OTLP exporter,
// `console` prints every finished span, and `none` disables export entirely
// (spans are recorded but not exported).
//
// `endpoint` and `headers` override the values read from the
// OTEL_EXPORTER_OTLP_* environment variables, `resource` replaces the
// resource built from the environment, `resource_attributes` are merged into
// it, and `span_limits` replaces the limits read from the OTEL_SPAN_*
// environment variables. Spans are handed to the background task when they
// end and sent in coalesced batches; pending spans are drained when the task
// group exits.
//
// When `use_batch` is true (or an explicit `batch` configuration is supplied),
// a `BatchSpanProcessor` is installed in front of the async exporter and a
// background flush loop is started in `group`. The batch defaults come from
// the standard OTEL_BSP_* variables. By default the async exporter's own queue
// performs the batching.
//
// The provider is installed as the process-wide provider unless
// `install_global` is false, which keeps it private (useful when several
// providers coexist in one process, or in tests where a global shutdown from
// unrelated code must not flush this provider's spans).

///|
pub fn[G] setup(
  group : @async.TaskGroup[G],
  service_name? : String,
  resource? : @sdk.Resource,
  resource_attributes? : Map[String, @sdk.AttributeValue],
  endpoint? : String,
  headers? : Map[String, String],
  sampler? : @sdk.Sampler,
  span_limits? : @sdk.SpanLimits,
  exporters? : Array[String],
  max_queue_size? : Int32,
  use_batch? : Bool,
  batch? : @sdk.BatchConfig,
  install_global? : Bool,
) -> @sdk.TracerProviderSdk {
  let base = @otlp.OtlpHttpConfig::from_env()
  let config : @otlp.OtlpHttpConfig = {
    ..base,
    endpoint: endpoint.unwrap_or(base.endpoint),
    traces_endpoint: match endpoint {
      Some(_) => None
      None => base.traces_endpoint
    },
    headers: headers.unwrap_or(base.headers),
  }
  let mut provider = @sdk.TracerProviderSdk::new(service_name?)
  match resource {
    Some(value) => provider = provider.with_resource(value)
    None => ()
  }
  match resource_attributes {
    Some(values) => provider = provider.with_resource_attributes(values)
    None => ()
  }
  match sampler {
    Some(value) => provider = provider.with_sampler(value)
    None => ()
  }
  match span_limits {
    Some(value) => provider = provider.with_span_limits(value)
    None => ()
  }
  if @sdk.exporter_selected(exporters, "console") {
    let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(
      @sdk.ConsoleSpanExporter::new(),
    )
    provider = provider.with_span_processor(processor)
  }
  if @sdk.exporter_selected(exporters, "otlp") {
    let exporter = OtlpHttpAsyncSpanExporter::new(
      config,
      group,
      max_queue_size?,
    )
    let processor : &@sdk.SpanProcessor = match batch {
      // An explicit configuration always uses the batch processor.
      Some(config) => {
        let value = @sdk.BatchSpanProcessor::with_config(exporter, config)
        spawn_flush_loop(group, value)
        let processor : &@sdk.SpanProcessor = value
        processor
      }
      None =>
        if use_batch.unwrap_or(false) {
          // Queue/batch/interval defaults come from the OTEL_BSP_* variables.
          let value = @sdk.BatchSpanProcessor::from_env(exporter)
          spawn_flush_loop(group, value)
          let processor : &@sdk.SpanProcessor = value
          processor
        } else {
          let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(
            exporter,
          )
          processor
        }
    }
    provider = provider.with_span_processor(processor)
    // The exporter's sender lives in `group`. Once the group exits the sender
    // is gone, so shut the provider down to stop accepting spans that could
    // never be exported. Defer registration order makes this run before the
    // exporter's final drain, so queued spans are still flushed.
    group.add_defer(() => provider.shutdown())
  }
  if install_global.unwrap_or(true) {
    @sdk.set_global_tracer_provider(provider)
  }
  provider
}
