// The signal-specific endpoint is used verbatim except that a URL without a
// path part is sent to the root path. A network-path reference also has an
// authority but no path.

///|
test "network_path_traces_endpoint_gets_the_root_path" {
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="//collector:4318",
    ).traces_url(),
    "//collector:4318/",
  )
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="//collector:4318?tenant=acme",
    ).traces_url(),
    "//collector:4318/?tenant=acme",
  )
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="//collector:4318#fragment",
    ).traces_url(),
    "//collector:4318/#fragment",
  )
}

///|
test "network_path_traces_endpoint_with_a_path_is_unchanged" {
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="//collector:4318/custom/traces",
    ).traces_url(),
    "//collector:4318/custom/traces",
  )
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="///path",
    ).traces_url(),
    "///path",
  )
}
