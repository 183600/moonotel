// A span records whether its parent SpanContext came from a remote peer so
// exporters can encode OTLP Span.flags bits 8-9.

///|
fn parent_remote_test_tracer() -> (@sdk.Tracer, @sdk.InMemorySpanExporter) {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="parent-remote")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  (provider.get_tracer("parent-remote"), exporter)
}

///|
test "span_records_root_local_and_remote_parent_origin" {
  let (tracer, exporter) = parent_remote_test_tracer()
  let remote_parent = @api.span_context(
    @api.bytes_from_hex("0102030405060708090a0b0c0d0e0f10").unwrap(),
    @api.bytes_from_hex("1112131415161718").unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
    is_remote=true,
  )
  let root = tracer.start_root_span("root")
  let local_child = tracer.start_span("local-child", parent=root.context())
  let remote_child = tracer.start_span("remote-child", parent=remote_parent)
  // The SDK knows the parent state even for a root span: there is no remote
  // parent, which OTLP encodes as the "known, not remote" state.
  assert_eq(root.parent_is_remote(), Some(false))
  assert_eq(local_child.parent_is_remote(), Some(false))
  assert_eq(remote_child.parent_is_remote(), Some(true))
  root.end()
  local_child.end()
  remote_child.end()
  let spans = exporter.exported_spans()
  assert_eq(spans.length(), 3)
  assert_eq(spans[0].name, "root")
  assert_eq(spans[0].parent_is_remote, Some(false))
  assert_eq(spans[1].name, "local-child")
  assert_eq(spans[1].parent_is_remote, Some(false))
  assert_eq(spans[2].name, "remote-child")
  assert_eq(spans[2].parent_is_remote, Some(true))
  // The child's own SpanContext remains local even when its parent is remote.
  assert_false(remote_child.context().is_remote())
}
