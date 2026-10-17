// Service-name resolution: explicit argument > OTEL_SERVICE_NAME >
// `service.name` resource attribute > `unknown_service`, skipping blanks.

fn clear_service_name_env() -> Unit {
  @env.unset_env_var("OTEL_SERVICE_NAME")
  @env.unset_env_var("OTEL_RESOURCE_ATTRIBUTES")
}

fn service_name_of(provider : @sdk.TracerProviderSdk) -> @sdk.AttributeValue? {
  provider.resource().get(@sdk.SERVICE_NAME)
}

test "service_name_env_wins_over_resource_attribute" {
  clear_service_name_env()
  @env.set_env_var("OTEL_RESOURCE_ATTRIBUTES", "service.name=from-resource")
  @env.set_env_var("OTEL_SERVICE_NAME", "from-env")
  let provider = @sdk.TracerProviderSdk::new()
  clear_service_name_env()
  assert_eq(service_name_of(provider), Some(@sdk.StringValue("from-env")))
}

test "blank_service_name_env_falls_back_to_resource_attribute" {
  clear_service_name_env()
  @env.set_env_var("OTEL_RESOURCE_ATTRIBUTES", "service.name=from-resource")
  @env.set_env_var("OTEL_SERVICE_NAME", "   ")
  let provider = @sdk.TracerProviderSdk::new()
  clear_service_name_env()
  assert_eq(service_name_of(provider), Some(@sdk.StringValue("from-resource")))
}

test "blank_service_name_values_fall_back_to_unknown_service" {
  clear_service_name_env()
  @env.set_env_var("OTEL_RESOURCE_ATTRIBUTES", "service.name=")
  @env.set_env_var("OTEL_SERVICE_NAME", "")
  let provider = @sdk.TracerProviderSdk::new()
  clear_service_name_env()
  assert_eq(service_name_of(provider), Some(@sdk.StringValue("unknown_service")))
}

test "blank_explicit_service_name_falls_back_to_the_environment" {
  clear_service_name_env()
  @env.set_env_var("OTEL_SERVICE_NAME", "from-env")
  let provider = @sdk.TracerProviderSdk::new(service_name="")
  clear_service_name_env()
  assert_eq(service_name_of(provider), Some(@sdk.StringValue("from-env")))
}

test "resource_attribute_without_equals_is_skipped" {
  clear_service_name_env()
  @env.set_env_var("OTEL_RESOURCE_ATTRIBUTES", "novalue,service.name=svc")
  let provider = @sdk.TracerProviderSdk::new()
  clear_service_name_env()
  assert_eq(service_name_of(provider), Some(@sdk.StringValue("svc")))
}

test "non_ascii_percent_escape_in_resource_attribute_is_kept_verbatim" {
  clear_service_name_env()
  @env.set_env_var("OTEL_RESOURCE_ATTRIBUTES", "k=%éA")
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
  clear_service_name_env()
  assert_eq(provider.resource().get("k"), Some(@sdk.StringValue("%éA")))
}

test "blank_resource_service_name_falls_back_to_unknown_service" {
  clear_service_name_env()
  @env.set_env_var("OTEL_RESOURCE_ATTRIBUTES", "service.name=  ,other=kept")
  let provider = @sdk.TracerProviderSdk::new()
  clear_service_name_env()
  assert_eq(service_name_of(provider), Some(@sdk.StringValue("unknown_service")))
  assert_eq(provider.resource().get("other"), Some(@sdk.StringValue("kept")))
}
