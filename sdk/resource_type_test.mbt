// Tests for the first-class `Resource` type: construction, copy-on-write
// updates, merging and environment-based construction.

test "resource_empty_has_no_attributes" {
  let resource = @sdk.Resource::empty()
  assert_true(resource.is_empty())
  assert_eq(resource.length(), 0)
  assert_eq(resource.get("service.name"), None)
}

test "resource_new_copies_the_input_map" {
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("k", @sdk.StringValue("v"))
  let resource = @sdk.Resource::new(attributes=attributes)
  attributes.set("k", @sdk.StringValue("changed"))
  assert_eq(resource.get("k"), Some(@sdk.StringValue("v")))
  // The exported map is a copy as well, so it cannot mutate the resource.
  let exported = resource.attributes()
  exported.set("k", @sdk.StringValue("changed"))
  assert_eq(resource.get("k"), Some(@sdk.StringValue("v")))
}

test "resource_with_attribute_returns_a_copy" {
  let base = @sdk.Resource::empty().with_attribute("a", @sdk.StringValue("1"))
  let derived = base.with_attribute("b", @sdk.BoolValue(true))
  assert_eq(base.get("b"), None)
  assert_eq(derived.get("b"), Some(@sdk.BoolValue(true)))
  assert_eq(derived.get("a"), Some(@sdk.StringValue("1")))
}

test "resource_merge_prefers_the_other_resource" {
  let base = @sdk.Resource::new(
    attributes=Map([
      ("a", @sdk.StringValue("1")),
      ("b", @sdk.StringValue("1")),
    ]),
  )
  let other = @sdk.Resource::new(
    attributes=Map([
      ("b", @sdk.StringValue("2")),
      ("c", @sdk.StringValue("2")),
    ]),
  )
  let merged = base.merge(other)
  assert_eq(merged.get("a"), Some(@sdk.StringValue("1")))
  assert_eq(merged.get("b"), Some(@sdk.StringValue("2")))
  assert_eq(merged.get("c"), Some(@sdk.StringValue("2")))
  assert_eq(base.get("b"), Some(@sdk.StringValue("1")))
  assert_eq(other.get("a"), None)
}

test "resource_service_name_defaults_to_unknown_service" {
  assert_eq(@sdk.Resource::empty().service_name(), "unknown_service")
  assert_eq(
    @sdk.Resource::new(
      attributes=Map([("service.name", @sdk.StringValue("checkout"))]),
    ).service_name(),
    "checkout",
  )
  assert_eq(
    @sdk.Resource::new(
      attributes=Map([("service.name", @sdk.StringValue("   "))]),
    ).service_name(),
    "unknown_service",
  )
}

test "resource_from_env_matches_provider_defaults" {
  @env.unset_env_var("OTEL_SERVICE_NAME")
  @env.unset_env_var("OTEL_RESOURCE_ATTRIBUTES")
  let resource = @sdk.Resource::from_env()
  assert_eq(resource.service_name(), "unknown_service")
  assert_eq(
    resource.get(@sdk.TELEMETRY_SDK_NAME),
    Some(@sdk.StringValue("opentelemetry")),
  )
  assert_eq(
    resource.get(@sdk.TELEMETRY_SDK_LANGUAGE),
    Some(@sdk.StringValue("moonbit")),
  )
  assert_eq(
    resource.get(@sdk.TELEMETRY_SDK_VERSION),
    Some(@sdk.StringValue(@sdk.SDK_VERSION)),
  )
}

test "resource_from_env_reads_the_environment" {
  @env.set_env_var(
    "OTEL_RESOURCE_ATTRIBUTES",
    "deployment.environment=staging,service.version=1.0%2E0",
  )
  @env.set_env_var("OTEL_SERVICE_NAME", "checkout")
  let resource = @sdk.Resource::from_env()
  @env.unset_env_var("OTEL_RESOURCE_ATTRIBUTES")
  @env.unset_env_var("OTEL_SERVICE_NAME")
  assert_eq(resource.service_name(), "checkout")
  assert_eq(
    resource.get("deployment.environment"),
    Some(@sdk.StringValue("staging")),
  )
  assert_eq(resource.get("service.version"), Some(@sdk.StringValue("1.0.0")))
}

test "resource_from_env_prefers_the_explicit_service_name" {
  @env.set_env_var("OTEL_SERVICE_NAME", "from-env")
  let resource = @sdk.Resource::from_env(service_name="explicit")
  @env.unset_env_var("OTEL_SERVICE_NAME")
  assert_eq(resource.service_name(), "explicit")
}

test "provider_with_resource_replaces_the_default_resource" {
  let resource = @sdk.Resource::empty().with_attribute(
    @sdk.SERVICE_NAME,
    @sdk.StringValue("replaced"),
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="original")
    .with_resource(resource)
  assert_eq(
    provider.resource().get(@sdk.SERVICE_NAME),
    Some(@sdk.StringValue("replaced")),
  )
  assert_eq(provider.resource_object().service_name(), "replaced")
}

test "provider_resource_flows_into_exported_spans" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let resource = @sdk.Resource::new(
    attributes=Map([
      (@sdk.SERVICE_NAME, @sdk.StringValue("res-svc")),
      ("service.version", @sdk.StringValue("9.9.9")),
    ]),
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="ignored")
    .with_resource(resource)
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("resource-scope")
  let span = tracer.start_root_span("op")
  span.end()
  let spans = exporter.exported_spans()
  assert_eq(spans.length(), 1)
  assert_eq(
    spans[0].resource.get(@sdk.SERVICE_NAME),
    Some(@sdk.StringValue("res-svc")),
  )
  assert_eq(
    spans[0].resource.get("service.version"),
    Some(@sdk.StringValue("9.9.9")),
  )
}
