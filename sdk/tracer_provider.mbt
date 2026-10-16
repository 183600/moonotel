// The SDK TracerProvider: owns the resource, sampler, ID generator and span
// processors, and hands out Tracers. A process-wide provider can be installed
// with `set_global_tracer_provider`.

pub struct TracerProviderSdk {
  resource : Map[String, AttributeValue]
  sampler : Sampler
  id_generator : IdGenerator
  processors : Array[&SpanProcessor]
  mut shutdown_called : Bool
}

// Create a provider. The service name defaults to `OTEL_SERVICE_NAME` and
// falls back to `unknown_service`. The default sampler is
// ParentBased(AlwaysOn); the default ID generator produces random IDs.
pub fn TracerProviderSdk::new(service_name? : String) -> TracerProviderSdk {
  let name = match service_name {
    Some(value) => value
    None => @env.get_env_var("OTEL_SERVICE_NAME").unwrap_or("unknown_service")
  }
  let resource = Map::new()
  resource.set(SERVICE_NAME, StringValue(name))
  {
    resource,
    sampler: Sampler::parent_based(Sampler::always_on()),
    id_generator: IdGenerator::random(),
    processors: [],
    shutdown_called: false,
  }
}

// Add a resource attribute (e.g. `service.version`).
pub fn TracerProviderSdk::with_resource_attribute(
  self : TracerProviderSdk,
  key : String,
  value : AttributeValue
) -> TracerProviderSdk {
  self.resource.set(key, value)
  self
}

// Use a custom sampler.
pub fn TracerProviderSdk::with_sampler(
  self : TracerProviderSdk,
  sampler : Sampler
) -> TracerProviderSdk {
  { ..self, sampler, }
}

// Use a custom ID generator.
pub fn TracerProviderSdk::with_id_generator(
  self : TracerProviderSdk,
  id_generator : IdGenerator
) -> TracerProviderSdk {
  { ..self, id_generator, }
}

// Register a span processor (called in registration order).
pub fn TracerProviderSdk::with_span_processor(
  self : TracerProviderSdk,
  processor : &SpanProcessor
) -> TracerProviderSdk {
  self.processors.push(processor)
  self
}

// The resource attributes of this provider.
pub fn TracerProviderSdk::resource(self : TracerProviderSdk) -> Map[String, AttributeValue] {
  self.resource
}

// The sampler used by this provider.
pub fn TracerProviderSdk::sampler(self : TracerProviderSdk) -> Sampler {
  self.sampler
}

// Whether `shutdown` has been called.
pub fn TracerProviderSdk::is_shutdown(self : TracerProviderSdk) -> Bool {
  self.shutdown_called
}

// Create a tracer for the given instrumentation scope.
pub fn TracerProviderSdk::get_tracer(
  self : TracerProviderSdk,
  name : String,
  version? : String
) -> Tracer {
  {
    provider: self,
    scope_name: name,
    scope_version: version.unwrap_or(""),
  }
}

// Flush every registered processor.
pub fn TracerProviderSdk::force_flush(self : TracerProviderSdk) -> Unit {
  for processor in self.processors {
    processor.force_flush()
  }
}

// Flush and shut down every registered processor. Idempotent.
pub fn TracerProviderSdk::shutdown(self : TracerProviderSdk) -> Unit {
  if self.shutdown_called {
    return
  }
  self.shutdown_called = true
  for processor in self.processors {
    processor.shutdown()
  }
}

// Process-wide provider, installed by `set_global_tracer_provider`.
let global_provider : Ref[TracerProviderSdk?] = Ref(None)

// Install a process-wide TracerProvider.
pub fn set_global_tracer_provider(provider : TracerProviderSdk) -> Unit {
  global_provider.val = Some(provider)
}

// The process-wide TracerProvider, if one has been installed.
pub fn global_tracer_provider() -> TracerProviderSdk? {
  global_provider.val
}

// Convenience: create a tracer from the global provider. Panics when no
// global provider has been installed.
pub fn global_tracer(name : String, version? : String) -> Tracer {
  match global_provider.val {
    Some(provider) => provider.get_tracer(name, version?=version)
    None => abort("global TracerProvider is not initialized; call set_global_tracer_provider first")
  }
}

// Shut down and clear the process-wide provider, if any.
pub fn shutdown_global_tracer_provider() -> Unit {
  match global_provider.val {
    Some(provider) => {
      provider.shutdown()
      global_provider.val = None
    }
    None => ()
  }
}
