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
        for item in trimmed.split(",") {
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
  { ..self, processors, }
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

// Flush every registered processor.

///|
pub fn TracerProviderSdk::force_flush(self : TracerProviderSdk) -> Unit {
  for processor in self.processors {
    processor.force_flush()
  }
}

// Flush and shut down every registered processor. Idempotent.

///|
pub fn TracerProviderSdk::shutdown(self : TracerProviderSdk) -> Unit {
  if self.shutdown_called.val {
    return
  }
  self.shutdown_called.val = true
  for processor in self.processors {
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

// The process-wide TracerProvider, if one has been installed.

///|
pub fn global_tracer_provider() -> TracerProviderSdk? {
  global_provider.val
}

// Convenience: create a tracer from the global provider. Panics when no
// global provider has been installed.

///|
pub fn global_tracer(name : String, version? : String) -> Tracer {
  match global_provider.val {
    Some(provider) => provider.get_tracer(name, version?)
    None =>
      abort(
        "global TracerProvider is not initialized; call set_global_tracer_provider first",
      )
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
