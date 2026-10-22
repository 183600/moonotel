// `extract_parent` is the standalone entry point for reading a remote parent
// from request headers without running the full server wrapper.

///|
test "extract_parent returns the remote span context" {
  let headers : @http.Headers = Map([
    (
      @http.CaseInsensitiveString("traceparent"),
      "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01",
    ),
    (@http.CaseInsensitiveString("tracestate"), "congo=t61rcWkgMzE"),
  ])
  let parent = @async_http_server.extract_parent(headers).unwrap()
  assert_true(parent.is_valid())
  assert_true(parent.is_remote())
  assert_true(parent.is_sampled())
  assert_eq(parent.trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
  assert_eq(parent.span_id_hex(), "00f067aa0ba902b7")
  assert_eq(parent.tracestate(), "congo=t61rcWkgMzE")
}

///|
test "extract_parent ignores missing or invalid traceparent headers" {
  let empty_headers : @http.Headers = Map([])
  assert_true(@async_http_server.extract_parent(empty_headers) is None)
  let invalid : @http.Headers = Map([
    (
      @http.CaseInsensitiveString("traceparent"),
      "00-00000000000000000000000000000000-00f067aa0ba902b7-01",
    ),
  ])
  assert_true(@async_http_server.extract_parent(invalid) is None)
}
