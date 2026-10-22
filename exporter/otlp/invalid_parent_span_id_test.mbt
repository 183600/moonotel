// OTLP parent_span_id is either absent (root spans) or exactly 8 nonzero
// bytes. Malformed values on a directly constructed SpanData must not be
// written to the wire.

///|
fn parent_id_span(parent_span_id : Array[Int32]) -> @sdk.SpanData {
  { ..sample_span(), parent_span_id, }
}

///|
fn protobuf_parent_field(span : @sdk.SpanData) -> Array[Field] {
  let request = parse_fields(@otlp.encode_trace_request([span]).exact_view())
  let resource_spans = parse_fields(fields_of(request, 1)[0].payload)
  let scope_spans = parse_fields(first_of(resource_spans, 2).unwrap().payload)
  let span_fields = parse_fields(first_of(scope_spans, 2).unwrap().payload)
  fields_of(span_fields, 4)
}

///|
fn json_parent_text(span : @sdk.SpanData) -> String {
  @utf8.decode_lossy(@otlp.encode_trace_request_json([span]).exact_view())
}

///|
test "protobuf_omits_malformed_parent_span_ids" {
  assert_eq(protobuf_parent_field(parent_id_span([])).length(), 0)
  assert_eq(protobuf_parent_field(parent_id_span([1])).length(), 0)
  assert_eq(protobuf_parent_field(parent_id_span(Array::make(8, 0))).length(), 0)
  assert_eq(protobuf_parent_field(parent_id_span([1, 2, 3, 4, 5, 6, 7, 8])).length(), 1)
}

///|
test "json_omits_malformed_parent_span_ids" {
  assert_false(json_parent_text(parent_id_span([])).contains("\"parentSpanId\""))
  assert_false(json_parent_text(parent_id_span([1])).contains("\"parentSpanId\""))
  assert_false(
    json_parent_text(parent_id_span(Array::make(8, 0))).contains(
      "\"parentSpanId\"",
    ),
  )
  assert_true(
    json_parent_text(parent_id_span([1, 2, 3, 4, 5, 6, 7, 8])).contains(
      "\"parentSpanId\":\"0102030405060708\"",
    ),
  )
}
