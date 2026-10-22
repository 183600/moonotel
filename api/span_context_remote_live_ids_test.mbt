// A remote SpanContext whose aliased ID arrays were zeroed after construction
// is no longer usable and must not keep claiming a remote origin.

///|
fn remote_context_for_live_ids() -> @api.SpanContext {
  @api.span_context(
    Array::make(16, 1),
    Array::make(8, 2),
    1,
    is_remote=true,
  )
}

///|
test "zeroing_the_trace_id_clears_the_remote_flag" {
  let context = remote_context_for_live_ids()
  let trace_id = context.trace_id_view()
  for i = 0; i < trace_id.length(); i = i + 1 {
    trace_id[i] = 0
  }
  assert_false(context.is_remote())
  assert_false(context.with_remote(true).is_remote())
}

///|
test "zeroing_the_span_id_clears_the_remote_flag" {
  let context = remote_context_for_live_ids()
  let span_id = context.span_id_view()
  for i = 0; i < span_id.length(); i = i + 1 {
    span_id[i] = 0
  }
  assert_false(context.is_remote())
  assert_false(context.with_remote(true).is_remote())
}

///|
test "a_live_remote_context_stays_remote" {
  let context = remote_context_for_live_ids()
  assert_true(context.is_remote())
  assert_true(context.with_remote(true).is_remote())
}
