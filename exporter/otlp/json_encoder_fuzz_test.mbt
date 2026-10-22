// Randomized tests for the OTLP/JSON encoder.
//
// Every produced document must be valid JSON and must carry exactly the data
// of the span model, including the values that are easy to get wrong: control
// characters, quotes, backslashes, non-ASCII text, extreme integers and
// non-finite doubles.

///|
struct JfRng {
  state : Ref[Int64]
}

///|
fn JfRng::new(seed : Int64) -> JfRng {
  { state: Ref(seed) }
}

///|
fn JfRng::next(self : JfRng) -> Int64 {
  // xorshift64
  let mut x = self.state.val
  x = x ^ (x >> 12)
  x = x ^ (x << 25)
  x = x ^ (x >> 27)
  self.state.val = x
  x
}

///|
fn JfRng::below(self : JfRng, bound : Int) -> Int {
  let value = self.next() & 0x7FFFFFFFFFFFFFFFL
  (value % bound.to_int64()).to_int()
}

// Fragments that stress the JSON string escaping and the number formats.

///|
let jf_fragments : Array[String] = [
  "a", "b", "0", " ", "\"", "\\", "\n", "\r", "\t", "\u{0}", "\u{1f}", "/",
  "é", "🤣", "=", ",", ":", "{", "}", "[", "]", " ", "", "#", "'",
]

// Interesting double values, including the non-finite ones.

///|
let jf_doubles : Array[Double] = [
  0.0, -0.0, 1.0, -1.0, 0.5, 1.5, 3.14159265358979, 1.0e21, 1.0e-7, 1.0e300,
  1.0e-300, 1.7976931348623157e308, -1.7976931348623157e308, 5.0e-324,
  9007199254740992.0, 1.0e16, 1.0e17, 0.1, 0.2, 0.3,
]

// Interesting 64-bit integers.

///|
let jf_ints : Array[Int64] = [
  0L, 1L, -1L, 2L, -2L, 1000000L, -1000000L, 9223372036854775807L,
  -9223372036854775808L, 4294967296L, -4294967296L,
]

///|
// Timestamps are protobuf `fixed64` fields, so their JSON string form is the
// unsigned decimal value of the bit pattern (the encoder must not use the
// signed `Int64` formatter for them).

///|
fn jf_uint64_string(value : Int64) -> String {
  value.reinterpret_as_uint64().to_string()
}

///|
fn jf_random_text(rng : JfRng, max_fragments : Int) -> String {
  let sb = StringBuilder()
  let count = rng.below(max_fragments + 1)
  let mut i = 0
  while i < count {
    let fragment = jf_fragments[rng.below(jf_fragments.length())]
    sb.write_view(fragment[:])
    i = i + 1
  }
  sb.to_string()
}

///|
fn jf_random_bytes(rng : JfRng, count : Int) -> Array[Int32] {
  let bytes : Array[Int32] = Array(capacity=count)
  let mut i = 0
  while i < count {
    bytes.push(rng.below(256))
    i = i + 1
  }
  bytes
}

///|
fn jf_random_attribute_value(rng : JfRng) -> @sdk.AttributeValue {
  match rng.below(8) {
    0 => @sdk.StringValue(jf_random_text(rng, 4))
    1 => @sdk.BoolValue(rng.below(2) == 0)
    2 => @sdk.IntValue(jf_ints[rng.below(jf_ints.length())])
    3 => @sdk.DoubleValue(jf_doubles[rng.below(jf_doubles.length())])
    4 => {
      let count = rng.below(4)
      let items : Array[String] = Array(capacity=count)
      let mut i = 0
      while i < count {
        items.push(jf_random_text(rng, 3))
        i = i + 1
      }
      @sdk.StringArrayValue(items)
    }
    5 => {
      let count = rng.below(4)
      let items : Array[Bool] = Array(capacity=count)
      let mut i = 0
      while i < count {
        items.push(rng.below(2) == 0)
        i = i + 1
      }
      @sdk.BoolArrayValue(items)
    }
    6 => {
      let count = rng.below(4)
      let items : Array[Int64] = Array(capacity=count)
      let mut i = 0
      while i < count {
        items.push(jf_ints[rng.below(jf_ints.length())])
        i = i + 1
      }
      @sdk.IntArrayValue(items)
    }
    _ => {
      let count = rng.below(4)
      let items : Array[Double] = Array(capacity=count)
      let mut i = 0
      while i < count {
        items.push(jf_doubles[rng.below(jf_doubles.length())])
        i = i + 1
      }
      @sdk.DoubleArrayValue(items)
    }
  }
}

///|
fn jf_random_attributes(rng : JfRng, max_entries : Int) -> Map[String, @sdk.AttributeValue] {
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  let count = rng.below(max_entries + 1)
  let mut i = 0
  while i < count {
    attributes.set(jf_random_text(rng, 3), jf_random_attribute_value(rng))
    i = i + 1
  }
  attributes
}

///|
fn jf_random_span(rng : JfRng) -> @sdk.SpanData {
  let trace_id = jf_random_bytes(rng, 16)
  let span_id = jf_random_bytes(rng, 8)
  // All-zero identifiers are invalid and are never exported.
  while @api.is_zero(trace_id) {
    let _ = jf_random_bytes(rng, 16)
    trace_id[0] = 1
  }
  while @api.is_zero(span_id) {
    span_id[0] = 1
  }
  let event_count = rng.below(3)
  let events : Array[@sdk.SpanEvent] = Array(capacity=event_count)
  let mut i = 0
  while i < event_count {
    events.push({
      name: jf_random_text(rng, 4),
      time_unix_nano: jf_ints[rng.below(jf_ints.length())],
      attributes: jf_random_attributes(rng, 3),
      dropped_attributes_count: rng.below(3),
    })
    i = i + 1
  }
  let link_count = rng.below(3)
  let links : Array[@sdk.SpanLink] = Array(capacity=link_count)
  let mut j = 0
  while j < link_count {
    let link_trace_id = jf_random_bytes(rng, 16)
    link_trace_id[0] = 1
    let link_span_id = jf_random_bytes(rng, 8)
    link_span_id[0] = 1
    links.push({
      span_context: @api.span_context(
        link_trace_id,
        link_span_id,
        rng.below(4),
        tracestate=jf_random_text(rng, 3),
      ),
      attributes: jf_random_attributes(rng, 3),
      dropped_attributes_count: rng.below(3),
    })
    j = j + 1
  }
  let resource : Map[String, @sdk.AttributeValue] = Map([])
  resource.set("service.name", @sdk.StringValue(jf_random_text(rng, 3)))
  {
    name: jf_random_text(rng, 5),
    span_context: @api.span_context(
      trace_id,
      span_id,
      rng.below(4),
      tracestate=jf_random_text(rng, 3),
    ),
    parent_span_id: jf_random_bytes(rng, 8),
    kind: @api.SpanKind::Server,
    start_time_unix_nano: jf_ints[rng.below(jf_ints.length())],
    end_time_unix_nano: jf_ints[rng.below(jf_ints.length())],
    attributes: jf_random_attributes(rng, 4),
    events,
    links,
    dropped_attributes_count: rng.below(3),
    dropped_events_count: rng.below(3),
    dropped_links_count: rng.below(3),
    status: @api.StatusCode::Ok,
    status_description: jf_random_text(rng, 3),
    resource: @sdk.ResourceAttributes::new(resource),
    scope_name: jf_random_text(rng, 3),
    scope_version: jf_random_text(rng, 2),
  }
}

///|
fn jf_member(value : Json, key : String) -> Json {
  match value {
    Object(object) =>
      match object.get(key) {
        Some(entry) => entry
        None => abort("missing JSON member: " + key)
      }
    _ => abort("expected a JSON object")
  }
}

///|
fn jf_has_member(value : Json, key : String) -> Bool {
  match value {
    Object(object) => object.get(key) is Some(_)
    _ => false
  }
}

///|
fn jf_array(value : Json) -> Array[Json] {
  match value {
    Array(items) => items
    _ => abort("expected a JSON array")
  }
}

///|
fn jf_string(value : Json) -> String {
  match value {
    String(text) => text
    _ => abort("expected a JSON string")
  }
}

///|
fn jf_number(value : Json) -> Double {
  match value {
    Number(number, ..) => number
    _ => abort("expected a JSON number")
  }
}

///|
fn jf_check_any_value(
  json_value : Json,
  expected : @sdk.AttributeValue,
) -> Unit raise {
  match expected {
    @sdk.StringValue(text) =>
      assert_eq(jf_string(jf_member(json_value, "stringValue")), text)
    @sdk.BoolValue(flag) =>
      match jf_member(json_value, "boolValue") {
        True => assert_true(flag)
        False => assert_false(flag)
        _ => abort("expected a JSON boolean")
      }
    @sdk.IntValue(number) =>
      assert_eq(jf_string(jf_member(json_value, "intValue")), number.to_string())
    @sdk.DoubleValue(number) => {
      let encoded = jf_member(json_value, "doubleValue")
      match encoded {
        String(text) => {
          if number.is_nan() {
            assert_eq(text, "NaN")
          } else if number > 1.7976931348623157e308 {
            assert_eq(text, "Infinity")
          } else if number < -1.7976931348623157e308 {
            assert_eq(text, "-Infinity")
          } else {
            abort("unexpected string encoding for a finite double")
          }
        }
        _ => assert_eq(jf_number(encoded), number)
      }
    }
    @sdk.StringArrayValue(items) => {
      let values = jf_array(jf_member(jf_member(json_value, "arrayValue"), "values"))
      assert_eq(values.length(), items.length())
      let mut i = 0
      while i < items.length() {
        assert_eq(jf_string(jf_member(values[i], "stringValue")), items[i])
        i = i + 1
      }
    }
    @sdk.BoolArrayValue(items) => {
      let values = jf_array(jf_member(jf_member(json_value, "arrayValue"), "values"))
      assert_eq(values.length(), items.length())
      let mut i = 0
      while i < items.length() {
        match jf_member(values[i], "boolValue") {
          True => assert_true(items[i])
          False => assert_false(items[i])
          _ => abort("expected a JSON boolean")
        }
        i = i + 1
      }
    }
    @sdk.IntArrayValue(items) => {
      let values = jf_array(jf_member(jf_member(json_value, "arrayValue"), "values"))
      assert_eq(values.length(), items.length())
      let mut i = 0
      while i < items.length() {
        assert_eq(jf_string(jf_member(values[i], "intValue")), items[i].to_string())
        i = i + 1
      }
    }
    @sdk.DoubleArrayValue(items) => {
      let values = jf_array(jf_member(jf_member(json_value, "arrayValue"), "values"))
      assert_eq(values.length(), items.length())
      let mut i = 0
      while i < items.length() {
        let encoded = jf_member(values[i], "doubleValue")
        match encoded {
          String(text) => {
            let number = items[i]
            if number.is_nan() {
              assert_eq(text, "NaN")
            } else if number > 1.7976931348623157e308 {
              assert_eq(text, "Infinity")
            } else if number < -1.7976931348623157e308 {
              assert_eq(text, "-Infinity")
            } else {
              abort("unexpected string encoding for a finite double")
            }
          }
          _ => assert_eq(jf_number(encoded), items[i])
        }
        i = i + 1
      }
    }
  }
}

///|
fn jf_check_attributes(
  json_value : Json,
  attributes : Map[String, @sdk.AttributeValue],
) -> Unit raise {
  if attributes.length() == 0 {
    // Empty attribute maps are not written at all.
    assert_false(jf_has_member(json_value, "attributes"))
    return
  }
  let items = jf_array(jf_member(json_value, "attributes"))
  assert_eq(items.length(), attributes.length())
  for item in items {
    let key = jf_string(jf_member(item, "key"))
    match attributes.get(key) {
      Some(expected) => jf_check_any_value(jf_member(item, "value"), expected)
      None => abort("unexpected attribute: " + key)
    }
  }
}

///|
fn jf_check_span(json_span : Json, data : @sdk.SpanData) -> Unit raise {
  assert_eq(jf_string(jf_member(json_span, "name")), data.name)
  assert_eq(
    jf_string(jf_member(json_span, "traceId")),
    data.span_context.trace_id_hex(),
  )
  assert_eq(
    jf_string(jf_member(json_span, "spanId")),
    data.span_context.span_id_hex(),
  )
  assert_eq(
    jf_string(jf_member(json_span, "parentSpanId")),
    @api.bytes_to_hex(data.parent_span_id),
  )
  assert_eq(
    jf_string(jf_member(json_span, "startTimeUnixNano")),
    jf_uint64_string(data.start_time_unix_nano),
  )
  assert_eq(
    jf_string(jf_member(json_span, "endTimeUnixNano")),
    jf_uint64_string(data.end_time_unix_nano),
  )
  assert_eq(
    jf_number(jf_member(json_span, "kind")),
    data.kind.otlp_value().to_double(),
  )
  jf_check_attributes(json_span, data.attributes)
  if data.events.length() == 0 {
    // Empty event lists are not written at all.
    assert_false(jf_has_member(json_span, "events"))
  } else {
    let events = jf_array(jf_member(json_span, "events"))
    assert_eq(events.length(), data.events.length())
    let mut i = 0
    while i < events.length() {
      let event = data.events[i]
      let json_event = events[i]
      assert_eq(jf_string(jf_member(json_event, "name")), event.name)
      assert_eq(
        jf_string(jf_member(json_event, "timeUnixNano")),
        jf_uint64_string(event.time_unix_nano),
      )
      jf_check_attributes(json_event, event.attributes)
      i = i + 1
    }
  }
  if data.links.length() == 0 {
    // Empty link lists are not written at all.
    assert_false(jf_has_member(json_span, "links"))
  } else {
    let links = jf_array(jf_member(json_span, "links"))
    assert_eq(links.length(), data.links.length())
    let mut j = 0
    while j < links.length() {
      let link = data.links[j]
      let json_link = links[j]
      assert_eq(
        jf_string(jf_member(json_link, "traceId")),
        link.span_context.trace_id_hex(),
      )
      assert_eq(
        jf_string(jf_member(json_link, "spanId")),
        link.span_context.span_id_hex(),
      )
      jf_check_attributes(json_link, link.attributes)
      j = j + 1
    }
  }
  let status = jf_member(json_span, "status")
  if data.status_description == "" {
    // An empty message is not written.
    assert_false(jf_has_member(status, "message"))
  } else {
    assert_eq(
      jf_string(jf_member(status, "message")),
      data.status_description,
    )
  }
  assert_eq(
    jf_number(jf_member(status, "code")),
    data.status.otlp_value().to_double(),
  )
}

///|
fn jf_encode(spans : Array[@sdk.SpanData]) -> Json {
  let bytes = @otlp.encode_trace_request_json(spans)
  let text = @utf8.decode_lossy(bytes.exact_view())
  @json.parse(text) catch {
    err => abort("encoder produced invalid JSON: " + err.to_string() + " in " + text)
  }
}

///|
test "fuzz_json_encoder_produces_valid_documents" {
  let rng = JfRng::new(0x0DDB_1A5E_5EED_0001L)
  let mut i = 0
  while i < 200 {
    let data = jf_random_span(rng)
    let document = jf_encode([data])
    let groups = jf_array(jf_member(document, "resourceSpans"))
    assert_eq(groups.length(), 1)
    let scopes = jf_array(jf_member(groups[0], "scopeSpans"))
    assert_eq(scopes.length(), 1)
    let spans = jf_array(jf_member(scopes[0], "spans"))
    assert_eq(spans.length(), 1)
    jf_check_span(spans[0], data)
    i = i + 1
  }
}

///|
test "fuzz_json_encoder_groups_spans_by_resource" {
  let rng = JfRng::new(0x1CE0_1A5E_5EED_0002L)
  let mut i = 0
  while i < 100 {
    let first = jf_random_span(rng)
    let second = jf_random_span(rng)
    let document = jf_encode([first, second])
    let groups = jf_array(jf_member(document, "resourceSpans"))
    let mut found = false
    for group in groups {
      let scopes = jf_array(jf_member(group, "scopeSpans"))
      for scope in scopes {
        let spans = jf_array(jf_member(scope, "spans"))
        let mut j = 0
        while j < spans.length() {
          // Every span of the document must be one of the two inputs.
          let name = jf_string(jf_member(spans[j], "name"))
          assert_true(name == first.name || name == second.name)
          found = true
          j = j + 1
        }
      }
    }
    assert_true(found)
    i = i + 1
  }
}
