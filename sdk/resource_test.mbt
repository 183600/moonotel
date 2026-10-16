// Tests for resource construction: defaults, environment parsing and
// copy-on-write updates.

test "resource_includes_telemetry_sdk_attributes" {
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
  let resource = provider.resource()
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

test "resource_attributes_from_env" {
  @env.set_env_var(
    "OTEL_RESOURCE_ATTRIBUTES",
    "deployment.environment=prod,service.version=1.2%2E3",
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
  @env.unset_env_var("OTEL_RESOURCE_ATTRIBUTES")
  let resource = provider.resource()
  assert_eq(
    resource.get("deployment.environment"),
    Some(@sdk.StringValue("prod")),
  )
  assert_eq(resource.get("service.version"), Some(@sdk.StringValue("1.2.3")))
}

test "resource_attributes_decode_percent_with_surrogate_pair" {
  @env.set_env_var("OTEL_RESOURCE_ATTRIBUTES", "note=smile😀%41")
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
  @env.unset_env_var("OTEL_RESOURCE_ATTRIBUTES")
  assert_eq(
    provider.resource().get("note"),
    Some(@sdk.StringValue("smile😀A")),
  )
}

test "service_name_falls_back_to_resource_attributes" {
  @env.set_env_var("OTEL_RESOURCE_ATTRIBUTES", "service.name=from-resource")
  let provider = @sdk.TracerProviderSdk::new()
  @env.unset_env_var("OTEL_RESOURCE_ATTRIBUTES")
  assert_eq(
    provider.resource().get(@sdk.SERVICE_NAME),
    Some(@sdk.StringValue("from-resource")),
  )
}

test "explicit_service_name_wins_over_resource_attributes" {
  @env.set_env_var("OTEL_RESOURCE_ATTRIBUTES", "service.name=from-resource")
  let provider = @sdk.TracerProviderSdk::new(service_name="explicit")
  @env.unset_env_var("OTEL_RESOURCE_ATTRIBUTES")
  assert_eq(
    provider.resource().get(@sdk.SERVICE_NAME),
    Some(@sdk.StringValue("explicit")),
  )
}

test "with_resource_attributes_returns_a_copy" {
  let base = @sdk.TracerProviderSdk::new(service_name="svc")
  let extra : Map[String, @sdk.AttributeValue] = Map([])
  extra.set("k", @sdk.StringValue("v"))
  let derived = base.with_resource_attributes(extra)
  assert_eq(base.resource().get("k"), None)
  assert_eq(derived.resource().get("k"), Some(@sdk.StringValue("v")))
  assert_eq(
    derived.resource().get(@sdk.SERVICE_NAME),
    Some(@sdk.StringValue("svc")),
  )
}

test "child_span_inherits_parent_tracestate" {
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
  let tracer = provider.get_tracer("t")
  let parent = @api.span_context(
    [
      0x4b, 0xf9, 0x2f, 0x35, 0x9d, 0x1e, 0x75, 0xb7,
      0x61, 0x8a, 0x2d, 0x1f, 0x3c, 0x4e, 0x5a, 0x6b,
    ],
    [0x00, 0xf0, 0x67, 0xaa, 0x0b, 0xa9, 0x02, 0xb7],
    1,
    tracestate="vendor=value",
  )
  let child = tracer.start_span("child", parent=parent)
  assert_eq(child.context().tracestate(), "vendor=value")
  assert_eq(child.context().trace_id_hex(), parent.trace_id_hex())
}
