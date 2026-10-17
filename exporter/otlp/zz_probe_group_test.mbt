///|
fn probe_group_summaries(
  spans : Array[@sdk.SpanData]
) -> Array[(String, Int)] {
  let encoded = @otlp.encode_trace_request(spans)
  let request = parse_fields(encoded.exact_view())
  let out : Array[(String, Int)] = []
  for group in fields_of(request, 1) {
    let rs_fields = parse_fields(group.payload)
    let resource = parse_fields(first_of(rs_fields, 1).unwrap().payload)
    let attr = fields_of(resource, 1)[0]
    let kv = parse_fields(attr.payload)
    let key = first_of(kv, 1).unwrap().payload |> @utf8.decode_lossy
    let any = parse_fields(first_of(kv, 2).unwrap().payload)
    let value = first_of(any, 1).unwrap().payload |> @utf8.decode_lossy
    let mut span_count = 0
    for scope_spans in fields_of(rs_fields, 2) {
      span_count = span_count + fields_of(parse_fields(scope_spans.payload), 2).length()
    }
    out.push((key + "=" + value, span_count))
  }
  out
}

///|
test "consecutive_spans_share_same_resource_object" {
  let r : Map[String, @sdk.AttributeValue] = Map::new()
  r.set("a", @sdk.StringValue("v"))
  let groups = probe_group_summaries([
    probe_span_with(r),
    probe_span_with(r),
    probe_span_with(r),
  ])
  assert_eq(groups.length(), 1)
  assert_eq(groups[0].1, 3)
}

///|
test "interleaved_resources_round_trip" {
  let a : Map[String, @sdk.AttributeValue] = Map::new()
  a.set("a", @sdk.StringValue("A"))
  let b : Map[String, @sdk.AttributeValue] = Map::new()
  b.set("a", @sdk.StringValue("B"))
  let c : Map[String, @sdk.AttributeValue] = Map::new()
  c.set("a", @sdk.StringValue("C"))
  let groups = probe_group_summaries([
    probe_span_with(a),
    probe_span_with(b),
    probe_span_with(a),
    probe_span_with(c),
    probe_span_with(a),
    probe_span_with(b),
    probe_span_with(b),
  ])
  assert_eq(groups.length(), 3)
  assert_eq(groups[0], ("a=A", 3))
  assert_eq(groups[1], ("a=B", 3))
  assert_eq(groups[2], ("a=C", 1))
}

///|
test "resource_value_kinds_do_not_collide" {
  let kinds : Array[@sdk.AttributeValue] = [
    @sdk.BoolValue(true),
    @sdk.BoolValue(false),
    @sdk.DoubleValue(1.5),
    @sdk.DoubleValue(-0.0),
    @sdk.StringArrayValue(["x", "yy"]),
    @sdk.StringArrayValue([]),
    @sdk.BoolArrayValue([true, false]),
    @sdk.BoolArrayValue([]),
    @sdk.IntArrayValue([1L, 2L]),
    @sdk.IntArrayValue([]),
    @sdk.DoubleArrayValue([1.5, 2.5]),
    @sdk.DoubleArrayValue([]),
    @sdk.IntValue(1L),
    @sdk.StringValue("1"),
  ]
  for i = 0; i < kinds.length(); i = i + 1 {
    for j = i + 1; j < kinds.length(); j = j + 1 {
      let r1 : Map[String, @sdk.AttributeValue] = Map::new()
      r1.set("a", kinds[i])
      let r2 : Map[String, @sdk.AttributeValue] = Map::new()
      r2.set("a", kinds[j])
      let encoded = @otlp.encode_trace_request([
        probe_span_with(r1),
        probe_span_with(r2),
      ])
      let request = parse_fields(encoded.exact_view())
      let groups = fields_of(request, 1)
      assert_eq(groups.length(), 2)
    }
  }
}

///|
test "equal_content_resources_merge_into_one_group" {
  let r1 : Map[String, @sdk.AttributeValue] = Map::new()
  r1.set("a", @sdk.IntArrayValue([3L, 4L]))
  r1.set("b", @sdk.DoubleValue(2.0))
  let r2 : Map[String, @sdk.AttributeValue] = Map::new()
  r2.set("b", @sdk.DoubleValue(2.0))
  r2.set("a", @sdk.IntArrayValue([3L, 4L]))
  let encoded = @otlp.encode_trace_request([
    probe_span_with(r1),
    probe_span_with(r2),
  ])
  let request = parse_fields(encoded.exact_view())
  assert_eq(fields_of(request, 1).length(), 1)
}
