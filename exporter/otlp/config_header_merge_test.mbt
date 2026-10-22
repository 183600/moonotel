// `with_headers` layers programmatic headers over the configured environment
// headers. HTTP header names are case-insensitive, so an override must replace
// every spelling of the same name without discarding other headers.

///|
test "with_headers_overrides_case_insensitively_and_preserves_others" {
  let config = @otlp.OtlpHttpConfig::new(
    endpoint="http://collector:4318",
    headers=Map([
      ("x-env-only", "kept"),
      ("X-Token", "environment"),
      ("shared", "environment"),
    ]),
  )
  let merged = config.with_headers(Map([
    ("x-token", "programmatic"),
    ("Shared", "programmatic"),
    ("x-programmatic", "new"),
  ]))
  assert_eq(merged.headers.get("x-token"), Some("programmatic"))
  assert_eq(merged.headers.get("X-Token"), None)
  assert_eq(merged.headers.get("Shared"), Some("programmatic"))
  assert_eq(merged.headers.get("shared"), None)
  assert_eq(merged.headers.get("x-env-only"), Some("kept"))
  assert_eq(merged.headers.get("x-programmatic"), Some("new"))
  // The receiver is immutable; the source config still has its old values.
  assert_eq(config.headers.get("X-Token"), Some("environment"))
  assert_eq(config.headers.get("shared"), Some("environment"))
  assert_eq(config.headers.get("x-programmatic"), None)
}

///|
test "with_headers_does_not_alias_the_override_map" {
  let overrides : Map[String, String] = Map([("authorization", "Bearer one")])
  let merged = @otlp.OtlpHttpConfig::new(endpoint="http://collector:4318").with_headers(
    overrides,
  )
  overrides.set("authorization", "Bearer two")
  overrides.set("x-added-later", "1")
  assert_eq(merged.headers.get("authorization"), Some("Bearer one"))
  assert_eq(merged.headers.get("x-added-later"), None)
}
