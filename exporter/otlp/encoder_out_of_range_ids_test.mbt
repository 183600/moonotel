// Out-of-range ID values must be rendered the same way in every encoding:
// `format_traceparent`, OTLP/JSON and OTLP/protobuf all follow
// `@api.bytes_to_hex` for the same SpanContext.

///|
fn out_of_range_id_span() -> @sdk.SpanData {
  let span_context = @api.span_context(
    Array::make(16, 999),
    Array::make(8, -1),
    1,
  )
  {
    name: "out-of-range",
    span_context,
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map([]),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(Map([])),
    scope_name: "out-of-range",
    scope_version: "",
  }
}

///|
test "protobuf IDs match bytes_to_hex for out-of-range values" {
  let span = out_of_range_id_span()
  let expected_trace = @api.bytes_to_hex(span.span_context.trace_id())
  let expected_span = @api.bytes_to_hex(span.span_context.span_id())
  let encoded = @otlp.encode_trace_request([span])
  let request = parse_fields(encoded.exact_view())
  let resource_spans = parse_fields(fields_of(request, 1)[0].payload)
  let scope_spans = parse_fields(first_of(resource_spans, 2).unwrap().payload)
  let span_fields = parse_fields(first_of(scope_spans, 2).unwrap().payload)
  let trace_id = first_of(span_fields, 1).unwrap().payload
  let span_id = first_of(span_fields, 2).unwrap().payload
  assert_eq(
    @api.bytes_to_hex(trace_id.to_array().map(byte_to_int)),
    expected_trace,
  )
  assert_eq(
    @api.bytes_to_hex(span_id.to_array().map(byte_to_int)),
    expected_span,
  )
}

///|
test "JSON IDs match bytes_to_hex for out-of-range values" {
  let span = out_of_range_id_span()
  let expected_trace = @api.bytes_to_hex(span.span_context.trace_id())
  let expected_span = @api.bytes_to_hex(span.span_context.span_id())
  let json = @utf8.decode_lossy(@otlp.encode_trace_request_json([span]))
  assert_true(json.contains("\"traceId\":\"" + expected_trace + "\""))
  assert_true(json.contains("\"spanId\":\"" + expected_span + "\""))
}
