// `Tracer::with_span_async` must honor an explicit parent span while using the
// supplied context for baggage, exactly like the synchronous `with_span`.

///|
async test "with_span_async uses an explicit parent and context baggage" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="with-span-parent")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("with-span-parent")
  let parent = @api.span_context(
    @api.bytes_from_hex("0102030405060708090a0b0c0d0e0f10").unwrap(),
    @api.bytes_from_hex("1112131415161718").unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let base = @context.Context::root().with_value("tenant", "acme")
  let value = tracer.with_span_async(
    "child",
    span => {
      assert_eq(span.context().trace_id_hex(), parent.trace_id_hex())
      assert_eq(@api.bytes_to_hex(span.parent_span_id()), "1112131415161718")
      assert_eq(@context.current_context().value("tenant"), Some("acme"))
      42
    },
    context=base,
    parent~,
  )
  assert_eq(value, 42)
  let spans = exporter.exported_spans()
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].name, "child")
  assert_eq(spans[0].span_context.trace_id_hex(), parent.trace_id_hex())
  assert_eq(@api.bytes_to_hex(spans[0].parent_span_id), "1112131415161718")
  provider.shutdown()
}

///|
async test "with_span_async ends an explicitly parented span when raising" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="with-span-parent")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("with-span-parent")
  let parent = @api.span_context(
    @api.bytes_from_hex("11111111111111111111111111111111").unwrap(),
    @api.bytes_from_hex("2222222222222222").unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let raised = try {
    tracer.with_span_async("raising", _span => raise Failure("boom"), parent~)
    false
  } catch {
    _ => true
  }
  assert_true(raised)
  let spans = exporter.exported_spans()
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].name, "raising")
  assert_true(spans[0].end_time_unix_nano > 0L)
  assert_eq(spans[0].span_context.trace_id_hex(), parent.trace_id_hex())
  provider.shutdown()
}
