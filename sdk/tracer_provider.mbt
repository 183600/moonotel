// The SDK TracerProvider: owns the resource, sampler, ID generator and span
// processors, and hands out Tracers. A process-wide provider can be installed
// with `set_global_tracer_provider`.

///|
pub struct TracerProviderSdk {
  resource : Resource
  sampler : Sampler
  id_generator : IdGenerator
  span_limits : SpanLimits
  processors : Array[&SpanProcessor]
  disabled : Bool
  shutdown_called : Ref[Bool]
  // Guards the drain/shutdown sequence against reentry from a processor or
  // exporter. Shared with provider copies so a callback cannot start a second
  // concurrent drain of the same processors.
  draining : Ref[Bool]
  // Guards `force_flush` against reentry from a processor. A nested request on
  // the same processor set is a no-op; a copy only flushes processors the
  // outer pass does not own.
  flushing : Ref[Bool]
  // Processors currently owned by the outer `force_flush`. Shared with copies;
  // a nested flush on a copy skips those and still reaches processors added to
  // that copy.
  flushing_owner : Ref[Array[&SpanProcessor]?]
  // Shutdown requests made by a provider copy while another copy is already
  // draining. They run after the outer shutdown has finished, so the copy's
  // own processors are shut down without racing the outer drain.
  shutdown_waiters : Ref[Array[() -> Unit]]
  // Per-processor shutdown state, shared with provider copies that contain the
  // same processor. A processor added to a copy starts out unshut-down even
  // when the provider itself was already shut down.
  processor_shutdowns : Array[Ref[Bool]]
}

// Version reported as `telemetry.sdk.version` in the resource.

///|
pub const SDK_VERSION : String = "0.1.0"

// Whether `OTEL_SDK_DISABLED` requests a disabled SDK.

///|
fn sdk_disabled() -> Bool {
  match @env.get_env_var("OTEL_SDK_DISABLED") {
    Some(value) => value.trim().to_lower() == "true"
    None => false
  }
}

// Whether `OTEL_TRACES_EXPORTER` requests that no trace exporter be
// installed. `none` disables export wherever it appears in the
// comma-separated list; an unset or blank variable selects the default OTLP
// exporter.

///|
pub fn traces_exporter_disabled() -> Bool {
  match @env.get_env_var("OTEL_TRACES_EXPORTER") {
    Some(value) => {
      for item in value.split(",") {
        if item.trim().to_lower() == "none" {
          return true
        }
      }
      false
    }
    None => false
  }
}

// Whether `OTEL_TRACES_EXPORTER` requests the exporter named `name`
// (`otlp`, `console`, ...). The variable holds a comma-separated list that is
// matched case-insensitively; an unset or blank variable selects the default
// `otlp` exporter, and `none` anywhere in the list disables every exporter.

///|
pub fn traces_exporter_enabled(name : String) -> Bool {
  let wanted = name.trim().to_lower()
  match @env.get_env_var("OTEL_TRACES_EXPORTER") {
    None => wanted == "otlp"
    Some(value) => {
      let trimmed = value.trim()
      if trimmed == "" {
        wanted == "otlp"
      } else {
        let mut found = false
        let mut disabled = false
        let mut named = false
        for item in trimmed.split(",") {
          let item = item.trim().to_lower()
          if item == "" {
            continue
          }
          named = true
          if item == "none" {
            disabled = true
          } else if item == wanted {
            found = true
          }
        }
        // A list made only of separators/whitespace carries no exporter name,
        // so it behaves like an unset or blank variable.
        if !named {
          wanted == "otlp"
        } else {
          found && !disabled
        }
      }
    }
  }
}

// Whether the exporter named `name` is selected. An explicit `exporters` list
// is matched case-insensitively (an empty list selects nothing; `none`
// anywhere disables every exporter); when `exporters` is `None` the selection
// comes from `OTEL_TRACES_EXPORTER` via `traces_exporter_enabled`.

///|
pub fn exporter_selected(exporters : Array[String]?, name : String) -> Bool {
  match exporters {
    None => traces_exporter_enabled(name)
    Some(names) => {
      let wanted = name.trim().to_lower()
      let mut found = false
      let mut disabled = false
      for item in names {
        let item = item.trim().to_lower()
        if item == "none" {
          disabled = true
        } else if item == wanted {
          found = true
        }
      }
      found && !disabled
    }
  }
}

// Create a provider. The service name defaults to `OTEL_SERVICE_NAME`, then
// to `service.name` from `OTEL_RESOURCE_ATTRIBUTES`, and finally to
// `unknown_service`; blank values are skipped. The resource also carries the
// `telemetry.sdk.*` attributes. The default sampler follows
// `OTEL_TRACES_SAMPLER` (`parentbased_always_on` when unset), except when
// `OTEL_SDK_DISABLED=true`, in which case nothing is recorded or exported.
// The default ID generator produces random IDs.

///|
pub fn TracerProviderSdk::new(service_name? : String) -> TracerProviderSdk {
  let disabled = sdk_disabled()
  {
    resource: Resource::from_env(service_name?),
    sampler: if disabled {
      Sampler::always_off()
    } else {
      Sampler::from_env()
    },
    id_generator: IdGenerator::random(),
    span_limits: SpanLimits::from_env(),
    processors: [],
    disabled,
    shutdown_called: Ref(false),
    draining: Ref(false),
    flushing: Ref(false),
    flushing_owner: Ref(None),
    shutdown_waiters: Ref([]),
    processor_shutdowns: [],
  }
}

// Replace the whole resource of this provider, for example with one built by
// `Resource::from_env` and extended via `Resource::merge` or
// `Resource::with_attribute`.

///|
pub fn TracerProviderSdk::with_resource(
  self : TracerProviderSdk,
  resource : Resource,
) -> TracerProviderSdk {
  { ..self, resource, }
}

// Add a resource attribute (e.g. `service.version`).

///|
pub fn TracerProviderSdk::with_resource_attribute(
  self : TracerProviderSdk,
  key : String,
  value : AttributeValue,
) -> TracerProviderSdk {
  { ..self, resource: self.resource.with_attribute(key, value), }
}

// Add several resource attributes at once.

///|
pub fn TracerProviderSdk::with_resource_attributes(
  self : TracerProviderSdk,
  values : Map[String, AttributeValue],
) -> TracerProviderSdk {
  { ..self, resource: self.resource.merge(Resource::new(attributes=values)), }
}

// Merge the resources detected by `detectors` into the resource of this
// provider. The detected attributes override the ones already present, so a
// detector can refine the resource built from the environment. The detectors
// are merged in order, a later detector overriding an earlier one.

///|
pub fn TracerProviderSdk::with_resource_detectors(
  self : TracerProviderSdk,
  detectors : Array[&ResourceDetector],
) -> TracerProviderSdk {
  { ..self, resource: self.resource.merge(Resource::detect(detectors)), }
}

// Use a custom sampler.

///|
pub fn TracerProviderSdk::with_sampler(
  self : TracerProviderSdk,
  sampler : Sampler,
) -> TracerProviderSdk {
  { ..self, sampler, }
}

// Use a custom ID generator.

///|
pub fn TracerProviderSdk::with_id_generator(
  self : TracerProviderSdk,
  id_generator : IdGenerator,
) -> TracerProviderSdk {
  { ..self, id_generator, }
}

// Use custom span collection limits. By default the limits come from the
// OTEL_SPAN_* / OTEL_EVENT_* / OTEL_LINK_* environment variables, with the
// specification defaults (128 attributes, events and links per span).

///|
pub fn TracerProviderSdk::with_span_limits(
  self : TracerProviderSdk,
  span_limits : SpanLimits,
) -> TracerProviderSdk {
  { ..self, span_limits, }
}

// Register a span processor (called in registration order).

///|
pub fn TracerProviderSdk::with_span_processor(
  self : TracerProviderSdk,
  processor : &SpanProcessor,
) -> TracerProviderSdk {
  let processors = self.processors.copy()
  processors.push(processor)
  let processor_shutdowns = self.processor_shutdowns.copy()
  processor_shutdowns.push(Ref(false))
  { ..self, processors, processor_shutdowns, }
}

///|
pub fn TracerProviderSdk::with_span_processors(
  self : TracerProviderSdk,
  processors : Array[&SpanProcessor],
) -> TracerProviderSdk {
  let merged = self.processors.copy()
  for processor in processors {
    merged.push(processor)
  }
  let processor_shutdowns = self.processor_shutdowns.copy()
  for _ in processors {
    processor_shutdowns.push(Ref(false))
  }
  { ..self, processors: merged, processor_shutdowns, }
}

// The resource attributes of this provider, as a fresh copy.

///|
pub fn TracerProviderSdk::resource(
  self : TracerProviderSdk,
) -> Map[String, AttributeValue] {
  self.resource.attributes()
}

// The resource of this provider.

///|
pub fn TracerProviderSdk::resource_object(self : TracerProviderSdk) -> Resource {
  self.resource
}

// The sampler used by this provider.

///|
pub fn TracerProviderSdk::sampler(self : TracerProviderSdk) -> Sampler {
  self.sampler
}

// The span collection limits used by this provider.

///|
pub fn TracerProviderSdk::span_limits(self : TracerProviderSdk) -> SpanLimits {
  self.span_limits
}

// Number of span processors registered with this provider.

///|
pub fn TracerProviderSdk::processor_count(self : TracerProviderSdk) -> Int32 {
  self.processors.length()
}

// Whether `shutdown` has been called.

///|
pub fn TracerProviderSdk::is_shutdown(self : TracerProviderSdk) -> Bool {
  self.shutdown_called.val
}

// Create a tracer for the given instrumentation scope.

///|
pub fn TracerProviderSdk::get_tracer(
  self : TracerProviderSdk,
  name : String,
  version? : String,
) -> Tracer {
  { provider: self, scope_name: name, scope_version: version.unwrap_or(""), }
}

// Whether a processor array contains the same processor object.

///|
fn processor_in_array(
  processors : Array[&SpanProcessor],
  target : &SpanProcessor,
) -> Bool {
  for processor in processors {
    if physical_equal(processor, target) {
      return true
    }
  }
  false
}

///|
fn TracerProviderSdk::force_flush_processors(
  self : TracerProviderSdk,
  skip : Array[&SpanProcessor]?,
) -> Unit {
  for i, processor in self.processors {
    // A reentrant shutdown may have started while an earlier processor was
    // being flushed; the shutdown sequence drains and closes the remaining
    // processors.
    if self.draining.val {
      break
    }
    // A processor added to a copy of an already shut-down provider starts out
    // unshut-down (its own exporter is still open), so it can still be flushed
    // even though the provider's shared shutdown marker is set. Processors that
    // were already shut down must not be called again.
    if !self.processor_shutdowns[i].val &&
      !(match skip {
        Some(owner) => processor_in_array(owner, processor)
        None => false
      }) {
      processor.force_flush()
    }
  }
}

// Flush every registered processor.

///|
pub fn TracerProviderSdk::force_flush(self : TracerProviderSdk) -> Unit {
  // A shutdown in progress owns the processors.
  if self.draining.val {
    return
  }
  // A flush on the same processor set is a no-op. A flush on a copy only owns
  // processors the outer pass does not own, so run those instead of dropping
  // the request.
  if self.flushing.val {
    match self.flushing_owner.val {
      Some(owner) => {
        let previous = self.flushing_owner.val
        self.flushing_owner.val = Some(self.processors)
        defer { self.flushing_owner.val = previous }
        self.force_flush_processors(Some(owner))
      }
      None => ()
    }
    return
  }
  self.flushing.val = true
  let previous = self.flushing_owner.val
  self.flushing_owner.val = Some(self.processors)
  defer {
    self.flushing_owner.val = previous
    self.flushing.val = false
  }
  self.force_flush_processors(None)
}

// Flush and shut down every registered processor. Idempotent.

///|
pub fn TracerProviderSdk::shutdown(self : TracerProviderSdk) -> Unit {
  // A processor drain or processor shutdown may call back into `shutdown`
  // (for example an exporter that tears its provider down from `export_spans`).
  // The outer call owns the whole sequence; a reentrant call must not start
  // draining the same processors again. It may, however, belong to a provider
  // copy that has processors the outer call does not own, so queue it to run
  // after the outer shutdown completes.
  if self.draining.val {
    self.shutdown_waiters.val.push(() => self.shutdown())
    return
  }
  self.draining.val = true
  defer { self.draining.val = false }
  self.shutdown_called.val = true
  // Drain every not-yet-shut-down processor before shutting any exporter down.
  // Processors may share an exporter, and a simple processor registered before
  // a batch processor would otherwise close that exporter before the batch is
  // drained.
  for i, processor in self.processors {
    if !self.processor_shutdowns[i].val {
      processor.drain_before_shutdown()
    }
  }
  // A processor may have been in the middle of its own direct `shutdown` drain
  // when the exporter called back into the provider. That outer drain owns the
  // queues and the shared exporter; closing any processor here would make the
  // remaining queued spans fail to export. Ask the draining processor to run a
  // completion callback as soon as its drain is done, so the rest of the
  // provider's processors are still shut down exactly once without racing the
  // shared exporter.
  let mut draining = false
  for processor in self.processors {
    if processor.is_draining() {
      draining = true
      processor.set_shutdown_completion(() => self.shutdown())
    }
  }
  if draining {
    return
  }
  // Claim this provider's processors before running deferred copy shutdowns.
  // Copies share these markers; marking them first means a copy only handles
  // processors it added itself. The actual shutdown calls wait until after the
  // copies have drained, so a copy's new processor can still export through an
  // exporter shared with one of these processors.
  let to_shutdown : Array[&SpanProcessor] = Array(
    capacity=self.processors.length(),
  )
  let mut i = 0
  while i < self.processors.length() {
    if !self.processor_shutdowns[i].val {
      self.processor_shutdowns[i].val = true
      to_shutdown.push(self.processors[i])
    }
    i = i + 1
  }
  self.draining.val = false
  let waiters = self.shutdown_waiters.val
  self.shutdown_waiters.val = []
  for waiter in waiters {
    waiter()
  }
  for processor in to_shutdown {
    processor.shutdown()
  }
}

// Process-wide provider, installed by `set_global_tracer_provider`.

///|
let global_provider : Ref[TracerProviderSdk?] = Ref(None)

// Install a process-wide TracerProvider.

///|
pub fn set_global_tracer_provider(provider : TracerProviderSdk) -> Unit {
  global_provider.val = Some(provider)
}

// The process-wide provider, if one has been installed.

///|
pub fn global_tracer_provider() -> TracerProviderSdk? {
  global_provider.val
}

// The provider used when no process-wide provider has been installed. The
// OpenTelemetry specification requires the global TracerProvider to never be
// null, so an unset provider behaves like a no-op provider: its tracers are
// disabled and the spans they create are non-recording.

///|
let noop_provider : Ref[TracerProviderSdk?] = Ref(None)

///|
pub fn no_op_tracer_provider() -> TracerProviderSdk {
  match noop_provider.val {
    Some(provider) => provider
    None => {
      let provider = {
        resource: Resource::new(),
        sampler: Sampler::always_off(),
        id_generator: IdGenerator::random(),
        span_limits: SpanLimits::new(),
        processors: [],
        disabled: true,
        shutdown_called: Ref(false),
        draining: Ref(false),
        flushing: Ref(false),
        flushing_owner: Ref(None),
        shutdown_waiters: Ref([]),
        processor_shutdowns: [],
      }
      noop_provider.val = Some(provider)
      provider
    }
  }
}

// Convenience: create a tracer from the global provider. When no global
// provider has been installed a tracer from the no-op provider is returned
// instead, so that instrumentation never fails because of a missing setup
// call; the spans it creates are non-recording.

///|
pub fn global_tracer(name : String, version? : String) -> Tracer {
  match global_provider.val {
    Some(provider) => provider.get_tracer(name, version?)
    None => no_op_tracer_provider().get_tracer(name, version?)
  }
}

// Shut down and clear the process-wide provider, if any.

///|
pub fn shutdown_global_tracer_provider() -> Unit {
  match global_provider.val {
    Some(provider) => {
      provider.shutdown()
      global_provider.val = None
    }
    None => ()
  }
}

// Force-flush the process-wide provider, if any. Useful before an orderly
// process exit so that spans buffered by batch processors are exported.

///|
pub fn force_flush_global_tracer_provider() -> Unit {
  match global_provider.val {
    Some(provider) => provider.force_flush()
    None => ()
  }
}
