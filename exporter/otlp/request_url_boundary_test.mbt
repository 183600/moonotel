// Malformed and relative endpoints have no absolute `scheme://` prefix. They
// are passed to the transport unchanged, including an empty port, because the
// config documents that `traces_endpoint` is used verbatim unless it is a
// resolvable absolute URL or network-path reference.

///|
test "request_url_leaves_relative_and_malformed_endpoints_unchanged" {
  for
    traces_endpoint in [
      "collector:4318/custom", "http:/collector:/custom", "ht_tp://collector:/custom",
      "1http://collector:/custom",
    ] {
    assert_eq(
      @otlp.OtlpHttpConfig::new(traces_endpoint~).request_url(),
      traces_endpoint,
    )
  }
}

// An RFC 3986 empty port is stripped from a `userinfo@host` authority too. The
// userinfo (including its colon) must be preserved while the trailing colon of
// the host is removed.

///|
test "request_url_strips_an_empty_port_after_userinfo" {
  assert_eq(
    @otlp.OtlpHttpConfig::new(
      traces_endpoint="http://user:pass@collector:/custom",
    ).request_url(),
    "http://user:pass@collector/custom",
  )
  assert_eq(
    @otlp.OtlpHttpConfig::new(traces_endpoint="https://user@[::1]:/custom").request_url(),
    "https://user@[::1]/custom",
  )
}

// Non-HTTP schemes and malformed bracketed hosts are left untouched so their
// transport errors are unchanged.

///|
test "request_url_leaves_non_http_schemes_and_malformed_hosts_unchanged" {
  for
    traces_endpoint in [
      "ftp://collector:/file", "git+ssh://collector:/repo", "http://[::1]:4318/custom",
      "http://[::1]/custom", "http://[::1:/custom",
    ] {
    assert_eq(
      @otlp.OtlpHttpConfig::new(traces_endpoint~).request_url(),
      traces_endpoint,
    )
  }
}
