suberror ScratchErr {
  ScratchErr(String)
} derive(@debug.Debug)

test "scratch_error_strings_used_by_record_exception" {
  let e : Error = ScratchErr("boom")
  assert_true(e.to_string().contains("ScratchErr"))
  assert_true(@debug.to_string(e).contains("boom"))
  let f : Error = Failure("plain")
  assert_true(f.to_string().contains("plain"))
}

test "scratch_span_accessors_scope_version_and_provider_shutdown" {
  let provider = @sdk.TracerProviderSdk::new(service_name="scratch")
  let tracer = provider.get_tracer("scratch-scope", version="1.2.3")
  assert_eq(tracer.scope_version(), "1.2.3")
  assert_false(provider.is_shutdown())
  let span = tracer.start_root_span("op", start_time_unix_nano=5L)
  assert_eq(span.start_time_unix_nano(), 5L)
  span.end(end_time_unix_nano=7L)
  assert_eq(span.end_time_unix_nano(), 7L)
  provider.shutdown()
  assert_true(provider.is_shutdown())
}
