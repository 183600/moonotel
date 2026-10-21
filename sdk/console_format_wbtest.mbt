// The console exporter's rendered line is not asserted by the public tests
// (the test runner captures stdout), so the exact format is probed here to
// keep attribute values, the status description and event names visible to
// demos without changing the summary-line prefix.

///|
test "console format includes attributes and events" {
  let attributes : Map[String, AttributeValue] = Map([])
  attributes.set("http.method", StringValue("GET"))
  attributes.set("http.status_code", IntValue(200L))
  attributes.set("feature.enabled", BoolValue(true))
  attributes.set("ratio", DoubleValue(0.5))
  attributes.set("tags", StringArrayValue(["a", "b"]))
  let data : SpanData = {
    name: "GET /hello",
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Server,
    start_time_unix_nano: 0L,
    end_time_unix_nano: 3000000L,
    attributes,
    events: [
      {
        name: "request.started",
        time_unix_nano: 0L,
        attributes: Map([]),
        dropped_attributes_count: 0,
      },
    ],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Error,
    status_description: "boom",
    resource: ResourceAttributes::new(Map([])),
    scope_name: "probe",
    scope_version: "0.0.1",
  }
  let rendered = format_span(data)
  assert_true(rendered.contains("name=GET /hello"))
  assert_true(rendered.contains("kind=server"))
  assert_true(rendered.contains("status=error"))
  assert_true(rendered.contains("status_description=boom"))
  assert_true(rendered.contains("duration_ms=3"))
  assert_true(rendered.contains("attributes=5"))
  assert_true(rendered.contains("http.method=GET"))
  assert_true(rendered.contains("http.status_code=200"))
  assert_true(rendered.contains("feature.enabled=true"))
  assert_true(rendered.contains("ratio=0.5"))
  assert_true(rendered.contains("tags=[a, b]"))
  assert_true(rendered.contains("events=1"))
  assert_true(rendered.contains("request.started"))
}

///|
test "console format omits empty detail blocks" {
  let data : SpanData = {
    name: "internal",
    span_context: @api.span_context(
      @api.bytes_from_hex("11111111111111111111111111111111").unwrap(),
      @api.bytes_from_hex("2222222222222222").unwrap(),
      0,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 0L,
    end_time_unix_nano: 0L,
    attributes: Map([]),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: ResourceAttributes::new(Map([])),
    scope_name: "probe",
    scope_version: "0.0.1",
  }
  let rendered = format_span(data)
  assert_true(rendered.contains("attributes=0 events=0 links=0"))
  assert_false(rendered.contains("status_description="))
  assert_false(rendered.contains("{"))
  assert_false(rendered.contains("["))
}

///|
test "console format renders parent ids like bytes_to_hex" {
  let data : SpanData = {
    name: "parent",
    span_context: @api.span_context(
      @api.bytes_from_hex("33333333333333333333333333333333").unwrap(),
      @api.bytes_from_hex("4444444444444444").unwrap(),
      1,
    ),
    parent_span_id: [999, -1, 256, 0xAB],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 0L,
    end_time_unix_nano: 0L,
    attributes: Map([]),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: ResourceAttributes::new(Map([])),
    scope_name: "probe",
    scope_version: "0.0.1",
  }
  let rendered = format_span(data)
  assert_true(rendered.contains(" parent_span_id=070f00ab"))
  assert_true(
    rendered.contains(" parent_span_id=" + @api.bytes_to_hex(data.parent_span_id)),
  )
}
