// Accessor coverage for `SpanSdk` timestamps, status and the snapshot that is
// still readable after the span ended.

///|
fn accessor_status_span() -> (@sdk.SpanSdk, @sdk.InMemorySpanExporter) {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="span-accessors")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let span = provider
    .get_tracer("span-accessors")
    .start_root_span("op", start_time_unix_nano=100L)
  (span, exporter)
}

///|
test "span_reports_explicit_start_and_end_times" {
  let (span, exporter) = accessor_status_span()
  assert_eq(span.start_time_unix_nano(), 100L)
  assert_eq(span.end_time_unix_nano(), 0L)
  span.set_attribute("k", @sdk.StringValue("v"))
  span.end(end_time_unix_nano=250L)
  assert_eq(span.start_time_unix_nano(), 100L)
  assert_eq(span.end_time_unix_nano(), 250L)
  assert_true(span.is_ended())
  assert_false(span.is_recording())
  let data = exporter.exported_spans()[0]
  assert_eq(data.start_time_unix_nano, 100L)
  assert_eq(data.end_time_unix_nano, 250L)
}

///|
test "status_and_description_follow_the_ok_error_unset_order" {
  let (span, _exporter) = accessor_status_span()
  assert_eq(span.status(), @api.StatusCode::Unset)
  assert_eq(span.status_description(), "")

  span.set_status(@api.StatusCode::Error, description="boom")
  assert_eq(span.status(), @api.StatusCode::Error)
  assert_eq(span.status_description(), "boom")

  // An Unset attempt is ignored, including a supplied description.
  span.set_status(@api.StatusCode::Unset, description="ignored")
  assert_eq(span.status(), @api.StatusCode::Error)
  assert_eq(span.status_description(), "boom")

  // A later Error call records its own (empty) description.
  span.set_status(@api.StatusCode::Error)
  assert_eq(span.status(), @api.StatusCode::Error)
  assert_eq(span.status_description(), "")

  span.set_status(@api.StatusCode::Ok, description="ignored")
  assert_eq(span.status(), @api.StatusCode::Ok)
  assert_eq(span.status_description(), "")

  // Ok is final.
  span.set_status(@api.StatusCode::Error, description="late")
  assert_eq(span.status(), @api.StatusCode::Ok)
  assert_eq(span.status_description(), "")
}

///|
test "ended_span_collection_accessors_read_the_export_snapshot" {
  let (span, _exporter) = accessor_status_span()
  let parent = @api.span_context(Array::make(16, 3), Array::make(8, 4), 1)
  span.set_attribute("attr", @sdk.StringValue("value"))
  span.add_event("event")
  span.add_link(@sdk.SpanLink::new(parent))
  span.end()
  // The mutable collections were moved into the export snapshot; the public
  // accessors must keep reporting them.
  assert_eq(
    span.attributes().get("attr"),
    Some(@sdk.StringValue("value")),
  )
  assert_eq(span.events().length(), 1)
  assert_eq(span.events()[0].name, "event")
  assert_eq(span.links().length(), 1)
  assert_eq(span.links()[0].span_context.span_id_hex(), "0404040404040404")
}

///|
test "negative_value_length_limit_keeps_values_intact" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(
      service_name="negative-value-limit",
    )
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_limits(@sdk.SpanLimits::new(attribute_value_length_limit=-1))
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let span = provider
    .get_tracer("negative-value-limit")
    .start_root_span("op")
  span.set_attribute("long", @sdk.StringValue("abcdef"))
  span.end()
  assert_eq(
    exporter.exported_spans()[0].attributes.get("long"),
    Some(@sdk.StringValue("abcdef")),
  )
}

///|
test "truncation_drops_a_trailing_unpaired_high_surrogate" {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(
      service_name="surrogate-truncation",
    )
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_limits(@sdk.SpanLimits::new(attribute_value_length_limit=2))
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let high = String::from_array([(0xD800).unsafe_to_char()])
  let span = provider
    .get_tracer("surrogate-truncation")
    .start_root_span("op")
  // The cut would land right after the lone high surrogate; it is dropped so
  // the recorded value never contains half of a surrogate pair.
  span.set_attribute("value", @sdk.StringValue("a" + high + "b"))
  span.end()
  assert_eq(
    exporter.exported_spans()[0].attributes.get("value"),
    Some(@sdk.StringValue("a")),
  )
}
