// Tests for the `ResourceDetector` extension point: a detector contributes
// resource attributes, and the detected resources are merged in the order the
// detectors are given.

///|
pub struct StaticDetector {
  attributes : Map[String, @sdk.AttributeValue]
}

///|
pub fn StaticDetector::new(
  attributes : Map[String, @sdk.AttributeValue],
) -> StaticDetector {
  { attributes, }
}

///|
pub impl @sdk.ResourceDetector for StaticDetector with fn detect(self) {
  @sdk.Resource::new(attributes=self.attributes)
}

///|
pub extend StaticDetector with @sdk.ResourceDetector::{detect}

///|
test "resource_detect_merges_the_detectors_in_order" {
  let first = StaticDetector::new(
    Map([
      ("service.name", @sdk.StringValue("first")),
      ("host.name", @sdk.StringValue("alpha")),
    ]),
  )
  let second = StaticDetector::new(
    Map([
      ("service.name", @sdk.StringValue("second")),
      ("host.id", @sdk.StringValue("42")),
    ]),
  )
  let detected = @sdk.Resource::detect([first, second])
  // The later detector wins for the attributes both detectors provide.
  assert_eq(detected.get("service.name"), Some(@sdk.StringValue("second")))
  assert_eq(detected.get("host.name"), Some(@sdk.StringValue("alpha")))
  assert_eq(detected.get("host.id"), Some(@sdk.StringValue("42")))
  assert_eq(detected.length(), 3)
}

///|
test "resource_detect_without_detectors_is_empty" {
  let detected = @sdk.Resource::detect([])
  assert_true(detected.is_empty())
  assert_eq(detected.length(), 0)
}

///|
test "provider_merges_the_detected_resource_into_its_own" {
  let detector = StaticDetector::new(
    Map([
      ("service.version", @sdk.StringValue("2.0.0")),
      ("service.name", @sdk.StringValue("detected")),
    ]),
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="configured")
    .with_resource_detectors([detector])
  let attributes = provider.resource()
  // The detected attributes override the ones of the provider, the attributes
  // that only the provider carries are kept.
  assert_eq(attributes.get("service.name"), Some(@sdk.StringValue("detected")))
  assert_eq(
    attributes.get("service.version"),
    Some(@sdk.StringValue("2.0.0")),
  )
  assert_eq(
    attributes.get("telemetry.sdk.language"),
    Some(@sdk.StringValue("moonbit")),
  )
}

///|
test "provider_without_detectors_keeps_its_resource" {
  let provider = @sdk.TracerProviderSdk::new(service_name="configured")
    .with_resource_detectors([])
  let attributes = provider.resource()
  assert_eq(attributes.get("service.name"), Some(@sdk.StringValue("configured")))
}
