// Boundary behavior of the immutable `Tracestate` list: the 32-member limit
// and invalid mutations.

///|
fn tracestate_full() -> @propagation.Tracestate {
  let mut state = @propagation.Tracestate::empty()
  for i = 0; i < @propagation.TRACESTATE_MAX_MEMBERS; i = i + 1 {
    state = state.add("k" + i.to_string(), "v" + i.to_string())
  }
  state
}

///|
test "tracestate_add_to_a_full_list_drops_the_rightmost_member" {
  let state = tracestate_full()
  assert_eq(state.length(), @propagation.TRACESTATE_MAX_MEMBERS)
  let state = state.add("new", "value")
  assert_eq(state.length(), @propagation.TRACESTATE_MAX_MEMBERS)
  assert_eq(state.get("new"), Some("value"))
  // Members were added at the front, so the oldest `k0` is the right-most
  // member and is the one dropped.
  assert_eq(state.get("k0"), None)
  assert_eq(state.get("k1"), Some("v1"))
  assert_eq(state.get("k31"), Some("v31"))
}

///|
test "tracestate_add_replaces_a_duplicate_key_in_a_full_list" {
  let state = tracestate_full()
  let state = state.add("k5", "changed")
  assert_eq(state.length(), @propagation.TRACESTATE_MAX_MEMBERS)
  assert_eq(state.get("k5"), Some("changed"))
  // The replaced member is moved to the front, so nothing else is dropped.
  assert_eq(state.get("k0"), Some("v0"))
  assert_eq(state.get("k31"), Some("v31"))
}

///|
test "tracestate_update_moves_the_member_to_the_front" {
  let state = tracestate_full()
  let state = state.update("k7", "changed")
  assert_eq(state.length(), @propagation.TRACESTATE_MAX_MEMBERS)
  assert_eq(state.get("k7"), Some("changed"))
  assert_eq(state.entries()[0], ("k7", "changed"))
  // Replacing an existing key does not need to drop another member.
  assert_eq(state.get("k0"), Some("v0"))
  assert_eq(state.get("k31"), Some("v31"))
}

///|
test "tracestate_update_of_an_absent_key_is_a_noop" {
  let state = @propagation.Tracestate::parse("a=1,b=2").unwrap()
  let updated = state.update("missing", "value")
  assert_eq(updated.entries(), state.entries())
}

///|
test "tracestate_invalid_mutations_leave_the_list_unchanged" {
  let state = @propagation.Tracestate::parse("a=1").unwrap()
  assert_eq(state.add("Bad", "value").entries(), state.entries())
  assert_eq(state.add("b", "value ").entries(), state.entries())
  assert_eq(state.update("a", "value ").entries(), state.entries())
  assert_eq(state.remove("missing").entries(), state.entries())
}

///|
test "tracestate_parse_rejects_more_than_the_member_limit" {
  let sb = StringBuilder()
  for i = 0; i < @propagation.TRACESTATE_MAX_MEMBERS; i = i + 1 {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_string("k" + i.to_string() + "=v")
  }
  let at_limit = sb.to_string()
  assert_true(@propagation.Tracestate::parse(at_limit) is Some(_))
  assert_eq(@propagation.parse_tracestate(at_limit), Some(at_limit))
  let over_limit = at_limit + ",extra=1"
  assert_true(@propagation.Tracestate::parse(over_limit) is None)
  assert_eq(@propagation.parse_tracestate(over_limit), None)
}
