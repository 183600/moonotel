// A recording span remains readable after it ends even when its provider has
// no span processors (for example an SDK-only program that inspects spans
// directly). Ending the span must keep the recorded collections as a snapshot
// instead of clearing them without a reader.

///|
fn no_processor_span() -> @sdk.SpanSdk {
  let provider = @sdk.TracerProviderSdk::new(service_name="no-processors")
    .with_sampler(@sdk.Sampler::always_on())
  provider.get_tracer("no-processors").start_span("op")
}

///|
test "ended span keeps attributes without processors" {
  let span = no_processor_span()
  assert_true(span.is_recording())
  span.set_attribute("kept", @sdk.IntValue(7L))
  span.end()
  assert_false(span.is_recording())
  assert_true(span.is_ended())
  assert_eq(span.attributes().get("kept"), Some(@sdk.IntValue(7L)))
  assert_eq(span.attributes().length(), 1)
}

///|
test "ended span keeps events without processors" {
  let span = no_processor_span()
  span.add_event(
    "event",
    attributes=Map([("detail", @sdk.StringValue("kept"))]),
  )
  span.end()
  let events = span.events()
  assert_eq(events.length(), 1)
  assert_eq(events[0].name, "event")
  assert_eq(
    events[0].attributes.get("detail"),
    Some(@sdk.StringValue("kept")),
  )
}

///|
test "ended span keeps links without processors" {
  let span = no_processor_span()
  let linked = @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
  )
  span.add_link(
    @sdk.SpanLink::new(
      linked,
      attributes=Map([("kind", @sdk.StringValue("follows"))]),
    ),
  )
  span.end()
  let links = span.links()
  assert_eq(links.length(), 1)
  assert_eq(links[0].span_context.span_id_hex(), "00f067aa0ba902b7")
  assert_eq(
    links[0].attributes.get("kind"),
    Some(@sdk.StringValue("follows")),
  )
}

///|
test "ending a non-recording span still keeps the no-op state" {
  let provider = @sdk.TracerProviderSdk::new(service_name="no-processors")
    .with_sampler(@sdk.Sampler::always_off())
  let span = provider.get_tracer("no-processors").start_span("dropped")
  assert_false(span.is_recording())
  span.set_attribute("dropped", @sdk.StringValue("value"))
  span.end()
  assert_eq(span.attributes().length(), 0)
  assert_eq(span.events().length(), 0)
  assert_eq(span.links().length(), 0)
}
