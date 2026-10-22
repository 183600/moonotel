// Programmatic endpoint overrides follow the same blank/whitespace rules as
// the environment-variable path and `OtlpHttpConfig::new`.

///|
test "blank_endpoint_override_is_unset" {
  assert_eq(normalized_endpoint_override(None), None)
  assert_eq(normalized_endpoint_override(Some("")), None)
  assert_eq(normalized_endpoint_override(Some(" \t ")), None)
}

///|
test "nonblank_endpoint_override_is_trimmed" {
  assert_eq(
    normalized_endpoint_override(Some("  http://collector:4318  ")),
    Some("http://collector:4318"),
  )
  assert_eq(
    normalized_endpoint_override(Some("http://collector:4318")),
    Some("http://collector:4318"),
  )
}
