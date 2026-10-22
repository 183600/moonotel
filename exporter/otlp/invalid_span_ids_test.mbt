// OTLP requires a trace ID to be exactly 16 nonzero bytes and a span ID to be
// exactly 8. IDs shortened or zeroed after construction (through the read-only
// views) must not be serialized as malformed OTLP.

///|
fn short_id_context() -> @api.SpanContext {
  @api.span_context([7], [9], 1)
}

///|
fn short_id_span(name : String) -> @sdk.SpanData {
  { ..sample_span(), name, span_context: short_id_context() }
}

///|
fn json_text(spans : Array[@sdk.SpanData]) -> String {
  @utf8.decode_lossy(@otlp.encode_trace_request_json(spans).exact_view())
}

///|
test "protobuf_skips_spans_with_short_live_ids" {
  assert_eq(@otlp.encode_trace_request([short_id_span("short")]), b"")
  let mixed = [sample_span(), short_id_span("short")]
  assert_true(@otlp.encode_trace_request(mixed).length() > 0)
}

///|
test "json_skips_spans_with_short_live_ids" {
  assert_eq(@otlp.encode_trace_request_json([short_id_span("short")]), b"")
  let mixed = [sample_span(), short_id_span("short")]
  let text = json_text(mixed)
  assert_true(text.contains("\"GET /users\""))
  assert_false(text.contains("\"short\""))
}

///|
test "encoders_skip_spans_whose_ids_were_zeroed_after_construction" {
  let context = @api.span_context(Array::make(16, 1), Array::make(8, 2), 1)
  let trace_id = context.trace_id_view()
  for i = 0; i < trace_id.length(); i = i + 1 {
    trace_id[i] = 0
  }
  assert_true(context.is_valid())
  let span = { ..sample_span(), name: "zeroed", span_context: context }
  assert_eq(@otlp.encode_trace_request([span]), b"")
  assert_eq(@otlp.encode_trace_request_json([span]), b"")
}

///|
test "encoders_skip_spans_whose_ids_were_shortened_after_construction" {
  let context = @api.span_context(Array::make(16, 1), Array::make(8, 2), 1)
  context.trace_id_view().clear()
  context.trace_id_view().push(1)
  assert_false(context.is_valid())
  let span = { ..sample_span(), name: "shortened", span_context: context }
  assert_eq(@otlp.encode_trace_request([span]), b"")
  assert_eq(@otlp.encode_trace_request_json([span]), b"")
}

///|
test "protobuf_omits_unrepresentable_link_ids_but_keeps_attributes" {
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("link.reason", @sdk.StringValue("retry"))
  let span : @sdk.SpanData = {
    ..sample_span(),
    links: [@sdk.SpanLink::new(short_id_context(), attributes~)],
  }
  let span_fields = link_test_span_fields(span)
  let links = fields_of(span_fields, 13)
  assert_eq(links.length(), 1)
  let link = parse_fields(links[0].payload)
  assert_true(first_of(link, 1) is None)
  assert_true(first_of(link, 2) is None)
  assert_eq(fields_of(link, 4).length(), 1)
}

///|
test "json_omits_unrepresentable_link_ids_but_keeps_attributes" {
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("link.reason", @sdk.StringValue("retry"))
  let span : @sdk.SpanData = {
    ..sample_span(),
    links: [@sdk.SpanLink::new(short_id_context(), attributes~)],
  }
  let text = json_text([span])
  assert_false(text.contains("\"traceId\":\"07\""))
  assert_false(text.contains("\"spanId\":\"09\""))
  assert_true(text.contains("\"link.reason\""))
  assert_true(text.contains("\"retry\""))
}
