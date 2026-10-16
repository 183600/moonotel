// Regression tests: spans whose resources differ must be encoded as separate
// ResourceSpans groups. Grouping keys must distinguish values that merely look
// similar when flattened (delimiters inside strings, attribute value types).

fn probe_span_with(resource : Map[String, @sdk.AttributeValue]) -> @sdk.SpanData {
  {
    name: "probe",
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map::new(),
    events: [],
    status: @api.StatusCode::Unset,
    status_description: "",
    resource,
    scope_name: "scope",
    scope_version: "",
  }
}

fn probe_resource_group_count(
  r1 : Map[String, @sdk.AttributeValue],
  r2 : Map[String, @sdk.AttributeValue]
) -> Int {
  let encoded = @otlp.encode_trace_request([probe_span_with(r1), probe_span_with(r2)])
  let request = parse_fields(encoded.exact_view())
  fields_of(request, 1).length()
}

test "distinct_resources_with_delimiter_in_value_are_not_merged" {
  let r1 : Map[String, @sdk.AttributeValue] = Map::new()
  r1.set("a", @sdk.StringValue("b;c=d"))
  let r2 : Map[String, @sdk.AttributeValue] = Map::new()
  r2.set("a", @sdk.StringValue("b"))
  r2.set("c", @sdk.StringValue("d"))
  assert_eq(probe_resource_group_count(r1, r2), 2)
}

test "distinct_resources_with_same_text_different_types_are_not_merged" {
  let r1 : Map[String, @sdk.AttributeValue] = Map::new()
  r1.set("a", @sdk.IntValue(1L))
  let r2 : Map[String, @sdk.AttributeValue] = Map::new()
  r2.set("a", @sdk.StringValue("1"))
  assert_eq(probe_resource_group_count(r1, r2), 2)
}

test "identical_resources_share_one_group" {
  let r1 : Map[String, @sdk.AttributeValue] = Map::new()
  r1.set("a", @sdk.StringValue("b;c=d"))
  let r2 : Map[String, @sdk.AttributeValue] = Map::new()
  r2.set("a", @sdk.StringValue("b;c=d"))
  assert_eq(probe_resource_group_count(r1, r2), 1)
}
