///|
fn grouping_test_span(
  name : String,
  res : Map[String, @sdk.AttributeValue],
  scope : String,
) -> @sdk.SpanData {
  @sdk.SpanData::{
    name,
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      @api.TRACE_FLAGS_SAMPLED,
    ),
    parent_span_id: [],
    parent_is_remote: None,
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

///|
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

///|
test "grouping finds an existing scope before indexing the resource" {
  let ra : Map[String, @sdk.AttributeValue] = Map([
    ("service.name", @sdk.StringValue("a")),
  ])
  let rb : Map[String, @sdk.AttributeValue] = Map([
    ("service.name", @sdk.StringValue("b")),
  ])
  let spans = [
    grouping_test_span("a1", ra, "s1"),
    grouping_test_span("b1", rb, "s1"),
    grouping_test_span("a2", ra, "s1"),
  ]
  let groups = group_spans(spans)
  assert_eq(groups.length(), 2)
  let svc = match groups[0].resource.get("service.name") {
    Some(@sdk.StringValue(s)) => s
    _ => abort("missing service")
  }
  assert_eq(svc, "a")
  assert_eq(groups[0].scopes.length(), 1)
  assert_eq(groups[0].scopes[0].spans.length(), 2)
  assert_eq(groups[0].scopes[0].spans[0].name, "a1")
  assert_eq(groups[0].scopes[0].spans[1].name, "a2")
}

///|
test "grouping updates a scope index after adding a new scope" {
  let ra : Map[String, @sdk.AttributeValue] = Map([
    ("service.name", @sdk.StringValue("a")),
  ])
  let rb : Map[String, @sdk.AttributeValue] = Map([
    ("service.name", @sdk.StringValue("b")),
  ])
  let spans = [
    grouping_test_span("a1", ra, "s1"),
    grouping_test_span("a2", ra, "s2"),
    grouping_test_span("b1", rb, "s1"),
    grouping_test_span("a3", ra, "s3"),
    grouping_test_span("b2", rb, "s2"),
    grouping_test_span("a4", ra, "s2"),
    grouping_test_span("a5", ra, "s3"),
  ]
  let groups = group_spans(spans)
  assert_eq(groups.length(), 2)
  let group_a = groups[0]
  let svc = match group_a.resource.get("service.name") {
    Some(@sdk.StringValue(s)) => s
    _ => abort("missing service")
  }
  assert_eq(svc, "a")
  assert_eq(group_a.scopes.length(), 3)
  assert_eq(group_a.scopes[0].scope_name, "s1")
  assert_eq(group_a.scopes[0].spans.length(), 1)
  assert_eq(group_a.scopes[0].spans[0].name, "a1")
  assert_eq(group_a.scopes[1].scope_name, "s2")
  assert_eq(group_a.scopes[1].spans.length(), 2)
  assert_eq(group_a.scopes[1].spans[0].name, "a2")
  assert_eq(group_a.scopes[1].spans[1].name, "a4")
  assert_eq(group_a.scopes[2].scope_name, "s3")
  assert_eq(group_a.scopes[2].spans.length(), 2)
  assert_eq(group_a.scopes[2].spans[0].name, "a3")
  assert_eq(group_a.scopes[2].spans[1].name, "a5")
}

///|
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
