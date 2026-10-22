// The Trace API requires the copying/hex ID accessors to keep their canonical
// shapes even when a caller shortens an aliased ID array through a view. An
// invalid context also cannot claim to be remote.

///|
test "shortened_trace_id_is_reported_as_all_zero" {
  let context = @api.span_context(Array::make(16, 1), Array::make(8, 2), 1)
  let view = context.trace_id_view()
  view.clear()
  view.push(7)
  assert_false(context.is_valid())
  assert_eq(context.trace_id(), Array::make(16, 0))
  assert_eq(context.trace_id_hex(), "00000000000000000000000000000000")
}

///|
test "shortened_span_id_is_reported_as_all_zero" {
  let context = @api.span_context(Array::make(16, 1), Array::make(8, 2), 1)
  let view = context.span_id_view()
  view.clear()
  assert_false(context.is_valid())
  assert_eq(context.span_id(), Array::make(8, 0))
  assert_eq(context.span_id_hex(), "0000000000000000")
}

///|
test "growing_an_id_array_also_reports_the_canonical_shape" {
  let context = @api.span_context(Array::make(16, 1), Array::make(8, 2), 1)
  context.trace_id_view().push(3)
  context.span_id_view().push(4)
  assert_false(context.is_valid())
  assert_eq(context.trace_id().length(), 16)
  assert_eq(context.span_id().length(), 8)
  assert_eq(context.trace_id_hex().length(), 32)
  assert_eq(context.span_id_hex().length(), 16)
}

///|
test "valid_ids_are_unaffected_by_the_canonical_accessors" {
  let context = @api.span_context(Array::make(16, 1), Array::make(8, 2), 1)
  assert_eq(context.trace_id(), Array::make(16, 1))
  assert_eq(context.span_id(), Array::make(8, 2))
  assert_eq(context.trace_id_hex().length(), 32)
  assert_eq(context.span_id_hex().length(), 16)
}

///|
test "an_invalid_context_is_never_remote" {
  let invalid = @api.span_context(
    Array::make(1, 1),
    Array::make(1, 2),
    1,
    is_remote=true,
  )
  assert_false(invalid.is_valid())
  assert_false(invalid.is_remote())
  assert_false(invalid.with_remote(true).is_remote())
}

///|
test "a_valid_context_can_still_be_remote" {
  let valid = @api.span_context(
    Array::make(16, 1),
    Array::make(8, 2),
    1,
    is_remote=true,
  )
  assert_true(valid.is_remote())
  assert_true(valid.with_remote(true).is_remote())
}
