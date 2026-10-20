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

///|
pub struct Resource {
  attributes : Map[String, AttributeValue]
}

// Reverse table: the 0-15 value of each ASCII hex digit, -1 for every other
// code unit below 128.

///|
let hex_value : FixedArray[Int32] = build_hex_value()

///|
fn build_hex_value() -> FixedArray[Int32] {
  let table : FixedArray[Int32] = FixedArray::make(128, -1)
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

///|
fn hex_digit_value(c : Char) -> Int32 {
  let code = c.to_int()
  if code >= 0 && code < 128 {
    hex_value.unsafe_get(code)
  } else {
    -1
  }
}

// Decode the `%XX` sequences used by `OTEL_RESOURCE_ATTRIBUTES` values.
// Invalid sequences are kept verbatim.

///|
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

///|
fn parse_resource_attributes(
  value : String,
  resource : Map[String, AttributeValue],
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

///|
fn resolve_service_name(
  service_name : String?,
  resource : Map[String, AttributeValue],
) -> String {
  match service_name {
    Some(value) => if value.trim() != "" { return value }
    None => ()
  }
  match @env.get_env_var("OTEL_SERVICE_NAME") {
    Some(value) => if value.trim() != "" { return value }
    None => ()
  }
  match resource.get(SERVICE_NAME) {
    Some(StringValue(existing)) => if existing.trim() != "" { return existing }
    _ => ()
  }
  "unknown_service"
}

// Copy an attribute map so that a `Resource` owns its attributes and callers
// cannot mutate provider state through a shared map.

///|
fn copy_attributes_with_capacity(
  values : Map[String, AttributeValue],
  capacity : Int,
) -> Map[String, AttributeValue] {
  let out : Map[String, AttributeValue] = Map([], capacity~)
  for key, value in values {
    out.set(key, copy_attribute_value(value))
  }
  out
}

///|
fn copy_attributes(
  values : Map[String, AttributeValue],
) -> Map[String, AttributeValue] {
  copy_attributes_with_capacity(
    values,
    map_capacity_for_entries(values.length()),
  )
}

// An empty resource, carrying no attributes.

///|
pub fn Resource::empty() -> Resource {
  { attributes: Map([], capacity=1), }
}

// Create a resource from an attribute map. The map is copied.

///|
pub fn Resource::new(attributes? : Map[String, AttributeValue]) -> Resource {
  match attributes {
    Some(values) => { attributes: copy_attributes(values), }
    None => Resource::empty()
  }
}

// The attribute map of this resource, as a fresh copy.

///|
pub fn Resource::attributes(self : Resource) -> Map[String, AttributeValue] {
  copy_attributes(self.attributes)
}

// The attribute map backing this resource, shared with the caller. Callers
// must not mutate it.

///|
fn Resource::attributes_shared(self : Resource) -> Map[String, AttributeValue] {
  self.attributes
}

// The value of `key`, or None when the resource does not carry it.

///|
pub fn Resource::get(self : Resource, key : String) -> AttributeValue? {
  match self.attributes.get(key) {
    Some(value) => Some(copy_attribute_value(value))
    None => None
  }
}

// Number of attributes in this resource.

///|
pub fn Resource::length(self : Resource) -> Int32 {
  self.attributes.length()
}

// Whether the resource carries no attributes.

///|
pub fn Resource::is_empty(self : Resource) -> Bool {
  self.attributes.length() == 0
}

// Derive a resource with `key` set to `value`. The original is unchanged;
// an existing value of `key` is replaced.

///|
pub fn Resource::with_attribute(
  self : Resource,
  key : String,
  value : AttributeValue,
) -> Resource {
  let attributes = copy_attributes_with_capacity(
    self.attributes,
    map_capacity_for_entries(self.attributes.length() + 1),
  )
  attributes.set(key, copy_attribute_value(value))
  { attributes, }
}

// Merge `other` into this resource. Values from `other` win over values of
// this resource; neither input is modified.

///|
pub fn Resource::merge(self : Resource, other : Resource) -> Resource {
  let attributes = copy_attributes_with_capacity(
    self.attributes,
    map_capacity_for_entries(self.attributes.length() + other.attributes.length()),
  )
  for key, value in other.attributes {
    attributes.set(key, copy_attribute_value(value))
  }
  { attributes, }
}

// The `service.name` of this resource, or `unknown_service` when it is
// missing or blank.

///|
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

// A copy-on-write attribute map used for the resource carried by span
// snapshots. Every snapshot of a provider shares the provider's immutable
// resource map; the first `set` copies the outer map so that mutating one
// snapshot can never change the provider or any other span.

///|
pub struct ResourceAttributes {
  shared : Map[String, AttributeValue]
  mut own : Map[String, AttributeValue]?
}

// Wrap an attribute map as a resource snapshot. The map is not copied; the
// caller must not mutate it after handing it over (the SDK only hands over the
// provider's private resource map).

///|
pub fn ResourceAttributes::new(
  attributes : Map[String, AttributeValue],
) -> ResourceAttributes {
  { shared: attributes, own: None }
}

// The map backing this snapshot. The result is the shared map when the
// snapshot has not been written to, so callers must treat it as read-only.

///|
pub fn ResourceAttributes::as_map(
  self : ResourceAttributes,
) -> Map[String, AttributeValue] {
  match self.own {
    Some(map) => map
    None => self.shared
  }
}

// The value stored under `key`, if any.

///|
pub fn ResourceAttributes::get(
  self : ResourceAttributes,
  key : String,
) -> AttributeValue? {
  match self.own {
    Some(map) =>
      match map.get(key) {
        Some(value) => Some(copy_attribute_value(value))
        None => None
      }
    None =>
      match self.shared.get(key) {
        Some(value) => Some(copy_attribute_value(value))
        None => None
      }
  }
}

// Store `value` under `key`. The first write copies the shared map, so a
// snapshot can be mutated without affecting the provider or other spans.

///|
pub fn ResourceAttributes::set(
  self : ResourceAttributes,
  key : String,
  value : AttributeValue,
) -> Unit {
  let map = match self.own {
    Some(map) => map
    None => {
      let copied : Map[String, AttributeValue] = Map(
        [], capacity=map_capacity_for_entries(self.shared.length() + 1),
      )
      for entry_key, entry_value in self.shared {
        copied.set(entry_key, copy_attribute_value(entry_value))
      }
      self.own = Some(copied)
      copied
    }
  }
  map.set(key, copy_attribute_value(value))
}

// Number of attributes in this snapshot.

///|
pub fn ResourceAttributes::length(self : ResourceAttributes) -> Int32 {
  self.as_map().length()
}

// Whether this snapshot carries no attributes.

///|
pub fn ResourceAttributes::is_empty(self : ResourceAttributes) -> Bool {
  self.as_map().length() == 0
}

// Iterate the attributes of this snapshot in insertion order.

///|
pub fn ResourceAttributes::iter(
  self : ResourceAttributes,
) -> Iter[(String, AttributeValue)] {
  self.as_map().iter().map(fn(entry) {
    let (key, value) = entry
    (key, copy_attribute_value(value))
  })
}

///|
pub fn ResourceAttributes::iter2(
  self : ResourceAttributes,
) -> Iter2[String, AttributeValue] {
  let entries = self.as_map().iter()
  Iter2::new(fn() {
    match entries.next() {
      Some((key, value)) => Some((key, copy_attribute_value(value)))
      None => None
    }
  })
}

// Whether this snapshot stores a value under `key`.

///|
pub fn ResourceAttributes::contains(
  self : ResourceAttributes,
  key : String,
) -> Bool {
  self.as_map().contains(key)
}

// The value under `key`, or `default` when it is absent.

///|
pub fn ResourceAttributes::get_or_default(
  self : ResourceAttributes,
  key : String,
  default : AttributeValue,
) -> AttributeValue {
  match self.as_map().get(key) {
    Some(value) => copy_attribute_value(value)
    None => default
  }
}

// Remove `key` from this snapshot, copying the shared map first when needed.

///|
pub fn ResourceAttributes::remove(
  self : ResourceAttributes,
  key : String,
) -> Unit {
  match self.own {
    Some(map) => map.remove(key)
    None =>
      if self.shared.contains(key) {
        let copied : Map[String, AttributeValue] = copy_attributes(
          self.shared,
        )
        copied.remove(key)
        self.own = Some(copied)
      }
  }
}

// Remove every attribute from this snapshot.

///|
pub fn ResourceAttributes::clear(self : ResourceAttributes) -> Unit {
  if self.as_map().length() > 0 {
    self.own = Some(Map([]))
  }
}

// A copy of this snapshot whose mutations are independent.

///|
pub fn ResourceAttributes::copy(
  self : ResourceAttributes,
) -> ResourceAttributes {
  { shared: copy_attributes(self.as_map()), own: None }
}

// Iterators over the snapshot's keys and values, and its pairs as an array.

///|
pub fn ResourceAttributes::keys(self : ResourceAttributes) -> Iter[String] {
  self.as_map().keys()
}

///|
pub fn ResourceAttributes::values(
  self : ResourceAttributes,
) -> Iter[AttributeValue] {
  self.as_map().values().map(fn(value) { copy_attribute_value(value) })
}

///|
pub fn ResourceAttributes::to_array(
  self : ResourceAttributes,
) -> Array[(String, AttributeValue)] {
  let entries = self.as_map().to_array()
  for i, entry in entries {
    let (key, value) = entry
    entries[i] = (key, copy_attribute_value(value))
  }
  entries
}

///|
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
