// `Tracestate::is_empty` reports whether any member is present.

test "tracestate_is_empty" {
  assert_true(@propagation.Tracestate::empty().is_empty())
  assert_false(@propagation.Tracestate::parse("a=1").unwrap().is_empty())
}
