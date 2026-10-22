// Unpaired UTF-16 surrogates cannot be printed as UTF-8; the console exporter
// must escape them instead of handing invalid text to `println`.

///|
test "console escaping handles unpaired surrogates" {
  let high = String::from_array([(0xD800).unsafe_to_char()])
  let low = String::from_array([(0xDC00).unsafe_to_char()])
  assert_eq(escape_console_text("a" + high + "b"), "a\\ud800b")
  assert_eq(escape_console_text("a" + low + "b"), "a\\udc00b")
  assert_eq(escape_console_text(high + low), high + low)
}

///|
test "console format escapes unpaired surrogates in all text fields" {
  let high = String::from_array([(0xD800).unsafe_to_char()])
  let low = String::from_array([(0xDC00).unsafe_to_char()])
  let attributes : Map[String, AttributeValue] = Map([])
  attributes.set(
    "key" + high,
    StringValue("value" + low),
  )
  let data : SpanData = {
    name: "span" + high,
    span_context: @api.span_context(
      @api.bytes_from_hex("77777777777777777777777777777777").unwrap(),
      @api.bytes_from_hex("8888888888888888").unwrap(),
      1,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 0L,
    end_time_unix_nano: 0L,
    attributes,
    events: [
      {
        name: "event" + low,
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
    status_description: "bad" + high,
    resource: ResourceAttributes::new(Map([])),
    scope_name: "probe",
    scope_version: "0.0.1",
  }
  let rendered = format_span(data)
  assert_true(rendered.contains("name=span\\ud800"))
  assert_true(rendered.contains("key\\ud800=value\\udc00"))
  assert_true(rendered.contains("event\\udc00"))
  assert_true(rendered.contains("status_description=bad\\ud800"))
  // The rendered line is valid UTF-8 and can be printed.
  let _ = @utf8.decode(@utf8.encode(rendered))
}
