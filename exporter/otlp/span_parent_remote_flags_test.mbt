// OTLP Span.flags bits 8-9 describe whether the span's parent came from a
// remote peer. A known local parent (including a root span) sets the "known"
// bit, and a remote parent sets both the "known" and "is remote" bits.

///|
fn parent_remote_test_span(parent_is_remote : Bool?) -> @sdk.SpanData {
  { ..sample_span(), parent_is_remote, }
}

///|
fn parent_remote_root_span(parent_is_remote : Bool?) -> @sdk.SpanData {
  { ..sample_span(), parent_span_id: [], parent_is_remote, }
}

///|
fn parent_remote_json_span(parent_is_remote : Bool?) -> Json {
  let root = encode_json([parent_remote_test_span(parent_is_remote)])
  json_span_of(json_array_value(json_member(root, "resourceSpans"))[0], 0)
}

///|
test "protobuf_flags_encode_parent_remote_state" {
  let remote = link_test_span_fields(parent_remote_test_span(Some(true)))
  assert_eq(fixed32_value(first_of(remote, 16).unwrap()), 0x301)
  let local_parent = link_test_span_fields(parent_remote_test_span(Some(false)))
  assert_eq(fixed32_value(first_of(local_parent, 16).unwrap()), 0x101)
  let unknown = link_test_span_fields(parent_remote_test_span(None))
  assert_eq(fixed32_value(first_of(unknown, 16).unwrap()), 0x1)
}

///|
test "protobuf_flags_mark_root_parent_state_known" {
  let root = link_test_span_fields(parent_remote_root_span(Some(false)))
  assert_eq(fixed32_value(first_of(root, 16).unwrap()), 0x101)
}

///|
test "json_flags_mark_root_parent_state_known" {
  let root = encode_json([parent_remote_root_span(Some(false))])
  let span = json_span_of(
    json_array_value(json_member(root, "resourceSpans"))[0],
    0,
  )
  assert_eq(json_number_value(json_member(span, "flags")), 257.0)
}

///|
test "json_flags_encode_parent_remote_state" {
  assert_eq(
    json_number_value(json_member(parent_remote_json_span(Some(true)), "flags")),
    769.0,
  )
  assert_eq(
    json_number_value(
      json_member(parent_remote_json_span(Some(false)), "flags"),
    ),
    257.0,
  )
  assert_eq(
    json_number_value(json_member(parent_remote_json_span(None), "flags")),
    1.0,
  )
}
