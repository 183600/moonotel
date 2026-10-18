// First-class resource: the immutable set of attributes describing the entity
// that produces telemetry (service name, service version, deployment
// environment, ...). The provider attaches one resource to every span it
// creates, and the OTLP encoder emits it as the `ResourceSpans.resource`
// message.
//
// `Resource::from_env` implements the standard environment handling:
// `OTEL_RESOURCE_ATTRIBUTES` is parsed (keys and values are percent-decoded),
// the service name is resolved from the explicit argument, `OTEL_SERVICE_NAME`
// and the `service.name` attribute (blank values are skipped, in that order),
// and the `telemetry.sdk.*` attributes are added.

pub struct Resource {
  attributes : Map[String, AttributeValue]
}

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
// Both keys and values are percent-decoded, as required by the specification.
fn parse_resource_attributes(
  value : String,
  resource : Map[String, AttributeValue]
) -> Unit {
  for pair in value.split(",") {
    match pair.trim().split_once("=") {
      Some((key, raw_value)) => {
        let name = decode_percent(key.trim())
        if name != "" {
          resource.set(name, StringValue(decode_percent(raw_value.trim())))
        }
      }
      None => ()
    }
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

// Copy an attribute map so that a `Resource` owns its attributes and callers
// cannot mutate provider state through a shared map.
fn copy_attributes_with_capacity(
  values : Map[String, AttributeValue],
  capacity : Int
) -> Map[String, AttributeValue] {
  let out : Map[String, AttributeValue] = Map([], capacity=capacity)
  for key, value in values.iter2() {
    out.set(key, value)
  }
  out
}

fn copy_attributes(
  values : Map[String, AttributeValue]
) -> Map[String, AttributeValue] {
  copy_attributes_with_capacity(values, values.length() * 2)
}

// An empty resource, carrying no attributes.
pub fn Resource::empty() -> Resource {
  { attributes: Map([], capacity=1) }
}

// Create a resource from an attribute map. The map is copied.
pub fn Resource::new(
  attributes? : Map[String, AttributeValue]
) -> Resource {
  match attributes {
    Some(values) => { attributes: copy_attributes(values) }
    None => Resource::empty()
  }
}

// The attribute map of this resource, as a fresh copy.
pub fn Resource::attributes(
  self : Resource
) -> Map[String, AttributeValue] {
  copy_attributes(self.attributes)
}

// The attribute map backing this resource, shared with the caller. Callers
// must not mutate it.
fn Resource::attributes_shared(
  self : Resource
) -> Map[String, AttributeValue] {
  self.attributes
}

// The value of `key`, or None when the resource does not carry it.
pub fn Resource::get(self : Resource, key : String) -> AttributeValue? {
  self.attributes.get(key)
}

// Number of attributes in this resource.
pub fn Resource::length(self : Resource) -> Int {
  self.attributes.length()
}

// Whether the resource carries no attributes.
pub fn Resource::is_empty(self : Resource) -> Bool {
  self.attributes.length() == 0
}

// Derive a resource with `key` set to `value`. The original is unchanged;
// an existing value of `key` is replaced.
pub fn Resource::with_attribute(
  self : Resource,
  key : String,
  value : AttributeValue
) -> Resource {
  let attributes = copy_attributes_with_capacity(
    self.attributes,
    (self.attributes.length() + 1) * 2,
  )
  attributes.set(key, value)
  { attributes, }
}

// Merge `other` into this resource. Values from `other` win over values of
// this resource; neither input is modified.
pub fn Resource::merge(self : Resource, other : Resource) -> Resource {
  let attributes = copy_attributes_with_capacity(
    self.attributes,
    (self.attributes.length() + other.attributes.length()) * 2,
  )
  other.attributes.each(fn(key, value) { attributes.set(key, value) })
  { attributes, }
}

// The `service.name` of this resource, or `unknown_service` when it is
// missing or blank.
pub fn Resource::service_name(self : Resource) -> String {
  match self.attributes.get(SERVICE_NAME) {
    Some(StringValue(name)) =>
      if name.trim() != "" {
        name
      } else {
        "unknown_service"
      }
    _ => "unknown_service"
  }
}

// Build the resource from the standard environment variables:
//
// - `OTEL_RESOURCE_ATTRIBUTES` (percent-decoded `key=value` pairs)
// - `OTEL_SERVICE_NAME`, used when `service_name` is absent or blank
// - `service.name` from `OTEL_RESOURCE_ATTRIBUTES`, used last (a blank value
//   falls back to `unknown_service`)
//
// The `telemetry.sdk.name`, `telemetry.sdk.language` and
// `telemetry.sdk.version` attributes are always added and take precedence
// over same-named values from the environment.
pub fn Resource::from_env(service_name? : String) -> Resource {
  let attributes : Map[String, AttributeValue] = Map([])
  match @env.get_env_var("OTEL_RESOURCE_ATTRIBUTES") {
    Some(value) => parse_resource_attributes(value, attributes)
    None => ()
  }
  let name = resolve_service_name(service_name, attributes)
  attributes.set(SERVICE_NAME, StringValue(name))
  attributes.set(TELEMETRY_SDK_NAME, StringValue("opentelemetry"))
  attributes.set(TELEMETRY_SDK_LANGUAGE, StringValue("moonbit"))
  attributes.set(TELEMETRY_SDK_VERSION, StringValue(SDK_VERSION))
  { attributes, }
}
