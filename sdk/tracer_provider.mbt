// The SDK TracerProvider: owns the resource, sampler, ID generator and span
// processors, and hands out Tracers. A process-wide provider can be installed
// with `set_global_tracer_provider`.

pub struct TracerProviderSdk {
  resource : Map[String, AttributeValue]
  sampler : Sampler
  id_generator : IdGenerator
  span_limits : SpanLimits
  processors : Array[&SpanProcessor]
  mut shutdown_called : Bool
}

// Version reported as `telemetry.sdk.version` in the resource.
pub const SDK_VERSION : String = "0.1.0"

// Reverse table: the 0-15 value of each ASCII hex digit, -1 for every other
// code unit below 128.
let hex_value : FixedArray[Int] = build_hex_value()

fn build_hex_value() -> FixedArray[Int] {
  let table : FixedArray[Int] = FixedArray::make(128, -1)
  let mut i = 0
  while i < 10 {
    table.unsafe_set(48 + i, i)
    i = i + 1
  }
  let mut j = 0
  while j < 6 {
    table.unsafe_set(65 + j, 10 + j)
    table.unsafe_set(97 + j, 10 + j)
    j = j + 1
  }
  table
}

fn hex_digit_value(c : Char) -> Int {
  let code = c.to_int()
  if code >= 0 && code < 128 {
    hex_value.unsafe_get(code)
  } else {
    -1
  }
}

// Decode the `%XX` sequences used by `OTEL_RESOURCE_ATTRIBUTES` values.
// Invalid sequences are kept verbatim.
fn decode_percent(value : StringView) -> String {
  if value.find("%") is None {
    return value.to_owned()
  }
  let len = value.length()
  let bytes : Array[Byte] = Array(capacity=len)
  let mut i = 0
  while i < len {
    let c = value.unsafe_get(i).unsafe_to_char()
    if c == '%' && i + 2 < len {
      let hi = hex_digit_value(value.unsafe_get(i + 1).unsafe_to_char())
      let lo = hex_digit_value(value.unsafe_get(i + 2).unsafe_to_char())
      if hi >= 0 && lo >= 0 {
        bytes.push((hi * 16 + lo).to_byte())
        i = i + 3
        continue
      }
    }
    let code = c.to_int()
    if code < 0x80 {
      // ASCII characters encode to a single UTF-8 byte.
      bytes.push(code.to_byte())
      i = i + 1
    } else {
      // Encode a whole run of non-ASCII code units together so that surrogate
      // pairs are encoded as one character.
      let run_start = i
      let mut j = i
      while j < len {
        if value.unsafe_get(j).to_int() < 0x80 {
          break
        }
        j = j + 1
      }
      for byte in @utf8.encode(value.view(start_offset=run_start, end_offset=j)) {
        bytes.push(byte)
      }
      i = j
    }
  }
  @utf8.decode_lossy(Bytes::from_array(bytes).exact_view())
}

// Parse the `key=value,key2=value2` format of `OTEL_RESOURCE_ATTRIBUTES`.
fn parse_resource_attributes(
  value : String,
  resource : Map[String, AttributeValue]
) -> Unit {
  for pair in value.split(",") {
    match pair.trim().split_once("=") {
      Some((key, raw_value)) => {
        let name = key.trim().to_owned()
        if name != "" {
          resource.set(name, StringValue(decode_percent(raw_value.trim())))
        }
      }
      None => ()
    }
  }
}

// Whether `OTEL_SDK_DISABLED` requests a disabled SDK.
fn sdk_disabled() -> Bool {
  match @env.get_env_var("OTEL_SDK_DISABLED") {
    Some(value) => value.trim().to_lower() == "true"
    None => false
  }
}

// Whether `OTEL_TRACES_EXPORTER` requests that no trace exporter be
// installed (the value `none`). Every other value, including an unset
// variable, selects the default OTLP exporter.
pub fn traces_exporter_disabled() -> Bool {
  match @env.get_env_var("OTEL_TRACES_EXPORTER") {
    Some(value) => value.trim().to_lower() == "none"
    None => false
  }
}

// Resolve the service name from the explicit argument, `OTEL_SERVICE_NAME`
// and the `service.name` resource attribute, in that order. Blank values are
// treated as unset, as required by the OpenTelemetry specification.
fn resolve_service_name(
  service_name : String?,
  resource : Map[String, AttributeValue]
) -> String {
  match service_name {
    Some(value) =>
      if value.trim() != "" {
        return value
      }
    None => ()
  }
  match @env.get_env_var("OTEL_SERVICE_NAME") {
    Some(value) =>
      if value.trim() != "" {
        return value
      }
    None => ()
  }
  match resource.get(SERVICE_NAME) {
    Some(StringValue(existing)) =>
      if existing.trim() != "" {
        return existing
      }
    _ => ()
  }
  "unknown_service"
}

// Create a provider. The service name defaults to `OTEL_SERVICE_NAME`, then
// to `service.name` from `OTEL_RESOURCE_ATTRIBUTES`, and finally to
// `unknown_service`; blank values are skipped. The resource also carries the
// `telemetry.sdk.*` attributes. The default sampler follows
// `OTEL_TRACES_SAMPLER` (`parentbased_always_on` when unset), except when
// `OTEL_SDK_DISABLED=true`, in which case nothing is recorded or exported.
// The default ID generator produces random IDs.
pub fn TracerProviderSdk::new(service_name? : String) -> TracerProviderSdk {
  let resource = Map([])
  match @env.get_env_var("OTEL_RESOURCE_ATTRIBUTES") {
    Some(value) => parse_resource_attributes(value, resource)
    None => ()
  }
  let name = resolve_service_name(service_name, resource)
  resource.set(SERVICE_NAME, StringValue(name))
  resource.set(TELEMETRY_SDK_NAME, StringValue("opentelemetry"))
  resource.set(TELEMETRY_SDK_LANGUAGE, StringValue("moonbit"))
  resource.set(TELEMETRY_SDK_VERSION, StringValue(SDK_VERSION))
  {
    resource,
    sampler: if sdk_disabled() {
      Sampler::always_off()
    } else {
      Sampler::from_env()
    },
    id_generator: IdGenerator::random(),
    span_limits: SpanLimits::from_env(),
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
  let resource = Map([])
  self.resource.each(fn(existing_key, existing_value) {
    resource.set(existing_key, existing_value)
  })
  resource.set(key, value)
  { ..self, resource }
}

// Add several resource attributes at once.
pub fn TracerProviderSdk::with_resource_attributes(
  self : TracerProviderSdk,
  values : Map[String, AttributeValue]
) -> TracerProviderSdk {
  let resource = Map([])
  self.resource.each(fn(existing_key, existing_value) {
    resource.set(existing_key, existing_value)
  })
  values.each(fn(key, value) { resource.set(key, value) })
  { ..self, resource }
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

// Use custom span collection limits. By default the limits come from the
// OTEL_SPAN_* / OTEL_EVENT_* / OTEL_LINK_* environment variables, with the
// specification defaults (128 attributes, events and links per span).
pub fn TracerProviderSdk::with_span_limits(
  self : TracerProviderSdk,
  span_limits : SpanLimits
) -> TracerProviderSdk {
  { ..self, span_limits, }
}

// Register a span processor (called in registration order).
pub fn TracerProviderSdk::with_span_processor(
  self : TracerProviderSdk,
  processor : &SpanProcessor
) -> TracerProviderSdk {
  let processors = self.processors.copy()
  processors.push(processor)
  { ..self, processors }
}

// The resource attributes of this provider.
pub fn TracerProviderSdk::resource(self : TracerProviderSdk) -> Map[String, AttributeValue] {
  self.resource
}

// The sampler used by this provider.
pub fn TracerProviderSdk::sampler(self : TracerProviderSdk) -> Sampler {
  self.sampler
}

// The span collection limits used by this provider.
pub fn TracerProviderSdk::span_limits(self : TracerProviderSdk) -> SpanLimits {
  self.span_limits
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
