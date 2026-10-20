// Tests for the in-memory span exporter.

///|
test "in_memory_exporter_captures_exported_spans" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("mem-scope", version="1.0")
  let span = tracer.start_root_span("op")
  span.set_attribute("k", @sdk.StringValue("v"))
  span.end()
  assert_false(exporter.is_shutdown())
  assert_eq(exporter.span_count(), 1)
  let batches = exporter.exported_batches()
  assert_eq(batches.length(), 1)
  assert_eq(batches[0].length(), 1)
  let spans = exporter.exported_spans()
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].name, "op")
  assert_eq(spans[0].scope_name, "mem-scope")
  assert_eq(spans[0].scope_version, "1.0")
  assert_eq(spans[0].attributes.get("k"), Some(@sdk.StringValue("v")))
}

///|
test "in_memory_exporter_receives_only_sampled_spans" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem-drop")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_off())
  let tracer = provider.get_tracer("mem-scope")
  let span = tracer.start_root_span("dropped")
  span.end()
  assert_eq(exporter.span_count(), 0)
}

///|
test "in_memory_exporter_take_and_clear" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem-take")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("mem-scope")
  for name in ["a", "b"] {
    tracer.start_root_span(name).end()
  }
  let taken = exporter.take_spans()
  assert_eq(taken.length(), 2)
  assert_eq(taken[0].name, "a")
  assert_eq(taken[1].name, "b")
  assert_eq(exporter.span_count(), 0)
  tracer.start_root_span("c").end()
  assert_eq(exporter.span_count(), 1)
  exporter.clear()
  assert_eq(exporter.span_count(), 0)
}

///|
test "in_memory_exporter_empty_export_is_a_success" {
  let exporter = @sdk.InMemorySpanExporter::new()
  assert_eq(exporter.export_spans([]), @sdk.ExportSuccess)
  assert_eq(exporter.span_count(), 0)
}

///|
test "in_memory_exporter_rejects_exports_after_shutdown" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem-shutdown")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("mem-scope")
  let captured = tracer.start_root_span("before")
  captured.end()
  let taken = exporter.take_spans()
  exporter.shutdown()
  assert_true(exporter.is_shutdown())
  let result = exporter.export_spans(taken)
  assert_false(result.is_success())
  assert_eq(exporter.span_count(), 0)
}

///|
test "in_memory_exporter_returned_batches_are_copies" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem-copy")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  provider.get_tracer("mem-scope").start_root_span("one").end()
  let batches = exporter.exported_batches()
  batches[0].clear()
  assert_eq(exporter.span_count(), 1)
}

///|
test "in_memory_exporter_returned_spans_are_deep_copies" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem-deep-copy")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("mem-scope")
  let parent = @api.span_context(
    @api.bytes_from_hex("0102030405060708090a0b0c0d0e0f10").unwrap(),
    @api.bytes_from_hex("1112131415161718").unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let span = tracer.start_span("deep", parent~)
  span.set_string_array_attribute("k", ["a"])
  span.add_event("ev", attributes=Map([("e", @sdk.StringArrayValue(["e"]))]))
  span.add_link(
    @sdk.SpanLink::new(
      parent,
      attributes=Map([("l", @sdk.StringArrayValue(["l"]))]),
    ),
  )
  span.end()
  let first = exporter.exported_spans()[0]
  match first.attributes.get("k") {
    Some(@sdk.StringArrayValue(items)) => items.push("changed")
    _ => abort("expected a string array attribute")
  }
  first.attributes.set("injected", @sdk.StringValue("x"))
  match first.events[0].attributes.get("e") {
    Some(@sdk.StringArrayValue(items)) => items.push("changed")
    _ => abort("expected a string array attribute")
  }
  match first.links[0].attributes.get("l") {
    Some(@sdk.StringArrayValue(items)) => items.push("changed")
    _ => abort("expected a string array attribute")
  }
  first.resource.set("injected", @sdk.StringValue("x"))
  first.parent_span_id[0] = 99
  let batch = exporter.exported_batches()[0][0]
  batch.attributes.set("from_batch", @sdk.StringValue("x"))
  let again = exporter.exported_spans()[0]
  assert_eq(again.attributes.get("k"), Some(@sdk.StringArrayValue(["a"])))
  assert_eq(again.attributes.get("injected"), None)
  assert_eq(again.attributes.get("from_batch"), None)
  assert_eq(
    again.events[0].attributes.get("e"),
    Some(@sdk.StringArrayValue(["e"])),
  )
  assert_eq(
    again.links[0].attributes.get("l"),
    Some(@sdk.StringArrayValue(["l"])),
  )
  assert_eq(again.resource.get("injected"), None)
  assert_eq(@api.bytes_to_hex(again.parent_span_id), "1112131415161718")
}

///|
test "in_memory_exporter_isolates_stored_spans_from_input_mutations" {
  let trace_hex = "0102030405060708090a0b0c0d0e0f10"
  let parent_hex = "1112131415161718"
  let parent = @api.span_context(
    @api.bytes_from_hex(trace_hex).unwrap(),
    @api.bytes_from_hex(parent_hex).unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let source = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="mem-store-copy")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(source))
    .with_sampler(@sdk.Sampler::always_on())
  let span = provider.get_tracer("mem-scope").start_span("stored", parent~)
  span.set_string_array_attribute("k", ["a"])
  span.add_link(
    @sdk.SpanLink::new(
      parent,
      attributes=Map([("l", @sdk.StringArrayValue(["l"]))]),
    ),
  )
  span.end()
  let data = source.exported_spans()[0]
  let stored_span_id_hex = data.span_context.span_id_hex()
  let exporter = @sdk.InMemorySpanExporter::new()
  assert_eq(exporter.export_spans([data]), @sdk.ExportSuccess)
  let single = @sdk.InMemorySpanExporter::new()
  assert_eq(single.export_span(data), @sdk.ExportSuccess)
  data.span_context.trace_id_view()[0] = 99
  data.span_context.span_id_view()[0] = 99
  data.links[0].span_context.trace_id_view()[0] = 99
  data.links[0].span_context.span_id_view()[0] = 99
  data.parent_span_id[0] = 99
  data.attributes.set("after", @sdk.StringValue("x"))
  match data.attributes.get("k") {
    Some(@sdk.StringArrayValue(items)) => items.push("changed")
    _ => abort("expected a string array attribute")
  }
  match data.links[0].attributes.get("l") {
    Some(@sdk.StringArrayValue(items)) => items.push("changed")
    _ => abort("expected a string array attribute")
  }
  for target in [exporter, single] {
    let stored = target.exported_spans()[0]
    assert_eq(stored.span_context.trace_id_hex(), trace_hex)
    assert_eq(stored.span_context.span_id_hex(), stored_span_id_hex)
    assert_eq(stored.parent_span_id[0], 0x11)
    assert_eq(@api.bytes_to_hex(stored.parent_span_id), parent_hex)
    assert_eq(stored.links[0].span_context.trace_id_hex(), trace_hex)
    assert_eq(stored.links[0].span_context.span_id_hex(), parent_hex)
    assert_eq(stored.attributes.get("k"), Some(@sdk.StringArrayValue(["a"])))
    assert_eq(stored.attributes.get("after"), None)
    assert_eq(
      stored.links[0].attributes.get("l"),
      Some(@sdk.StringArrayValue(["l"])),
    )
  }
  let returned = exporter.exported_spans()[0]
  returned.span_context.trace_id_view()[0] = 77
  returned.links[0].span_context.trace_id_view()[0] = 78
  let again = exporter.exported_spans()[0]
  assert_eq(again.span_context.trace_id_hex(), trace_hex)
  assert_eq(again.links[0].span_context.trace_id_hex(), trace_hex)
}
