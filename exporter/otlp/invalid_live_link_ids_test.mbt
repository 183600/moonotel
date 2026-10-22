// A link whose SpanContext is invalid must not export IDs, even if a caller
// later fills the backing arrays with nonzero values through the public views.

///|
fn filled_but_invalid_context() -> @api.SpanContext {
  let context = @api.span_context(Array::make(16, 0), Array::make(8, 0), 1)
  let trace_id = context.trace_id_view()
  let span_id = context.span_id_view()
  for i = 0; i < trace_id.length(); i = i + 1 {
    trace_id[i] = 1
  }
  for i = 0; i < span_id.length(); i = i + 1 {
    span_id[i] = 2
  }
  context
}

///|
fn invalid_live_link_span() -> @sdk.SpanData {
  let attributes : Map[String, @sdk.AttributeValue] = Map([
    ("link.reason", @sdk.StringValue("retry")),
  ])
  {
    ..sample_span(),
    links: [@sdk.SpanLink::new(filled_but_invalid_context(), attributes~)],
  }
}

///|
test "protobuf_omits_ids_from_an_invalid_live_link_context" {
  let span = invalid_live_link_span()
  let link = parse_fields(
    fields_of(link_test_span_fields(span), 13)[0].payload,
  )
  assert_true(first_of(link, 1) is None)
  assert_true(first_of(link, 2) is None)
  assert_eq(fields_of(link, 4).length(), 1)
}

///|
test "json_omits_ids_from_an_invalid_live_link_context" {
  let text = @utf8.decode_lossy(
    @otlp.encode_trace_request_json([invalid_live_link_span()]).exact_view(),
  )
  assert_false(text.contains("\"traceId\":\"01010101010101010101010101010101\""))
  assert_false(text.contains("\"spanId\":\"0202020202020202\""))
  assert_true(text.contains("\"link.reason\""))
}
