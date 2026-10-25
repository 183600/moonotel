fn grouping_test_span(
  name : String,
  res : Map[String, @sdk.AttributeValue],
  scope : String
) -> @sdk.SpanData {
  @sdk.SpanData::{
    name,
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      @api.TRACE_FLAGS_SAMPLED,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map([]),
    events: [],
    links: [],
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(res),
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    scope_name: scope,
    scope_version: "",
  }
}

test "grouping keeps interleaved resources and scopes separate" {
  let ra : Map[String, @sdk.AttributeValue] = Map([
    ("service.name", @sdk.StringValue("a")),
    ("x", @sdk.IntValue(1)),
  ])
  let rb : Map[String, @sdk.AttributeValue] = Map([
    ("service.name", @sdk.StringValue("b")),
  ])
  let spans = [
    grouping_test_span("a1", ra, "s1"),
    grouping_test_span("b1", rb, "s1"),
    grouping_test_span("a2", ra, "s2"),
    grouping_test_span("a1b", ra, "s1"),
    grouping_test_span("b2", rb, "s2"),
    grouping_test_span("a2b", ra, "s2"),
    grouping_test_span("b1b", rb, "s1"),
  ]
  let groups = group_spans(spans)
  assert_eq(groups.length(), 2)
  let mut total = 0
  for group in groups {
    let svc = match group.resource.get("service.name") {
      Some(@sdk.StringValue(s)) => s
      _ => abort("missing service")
    }
    assert_eq(group.scopes.length(), 2)
    for scope in group.scopes {
      for span in scope.spans {
        let n = span.name
        let first = if n == "a1" || n == "a1b" {
          "a1"
        } else if n == "a2" || n == "a2b" {
          "a2"
        } else if n == "b1" || n == "b1b" {
          "b1"
        } else {
          "b2"
        }
        let want_svc = if first.has_prefix("a") { "a" } else { "b" }
        let want_scope = if first == "a1" || first == "b1" {
          "s1"
        } else {
          "s2"
        }
        assert_eq(svc, want_svc)
        assert_eq(scope.scope_name, want_scope)
        total = total + 1
      }
    }
  }
  assert_eq(total, 7)
}

test "resource keys distinguish attribute value types" {
  let values : Array[@sdk.AttributeValue] = [
    @sdk.StringValue("1"),
    @sdk.BoolValue(true),
    @sdk.IntValue(1),
    @sdk.DoubleValue(1.0),
    @sdk.StringArrayValue(["1"]),
    @sdk.BoolArrayValue([true]),
    @sdk.IntArrayValue([1L]),
    @sdk.DoubleArrayValue([1.0]),
  ]
  let keys : Array[String] = []
  for v in values {
    let m : Map[String, @sdk.AttributeValue] = Map([("k", v)])
    keys.push(resource_key(m))
  }
  let mut i = 0
  while i < keys.length() {
    let mut j = i + 1
    while j < keys.length() {
      assert_true(keys[i] != keys[j])
      j = j + 1
    }
    i = i + 1
  }
}
