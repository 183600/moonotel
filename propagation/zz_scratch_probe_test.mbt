// Tests for the immutable `Tracestate` operations (add / update / remove).

test "tracestate_parse_basic" {
  let ts = @propagation.Tracestate::parse("a=1,b=2").unwrap()
  assert_eq(ts.length(), 2)
  assert_eq(ts.entries(), [("a", "1"), ("b", "2")])
  assert_eq(ts.to_header(), "a=1,b=2")
  assert_eq(ts.get("a"), Some("1"))
  assert_eq(ts.get("b"), Some("2"))
  assert_eq(ts.get("c"), None)
}

test "tracestate_parse_trims_ows_and_reorders_nothing" {
  let ts = @propagation.Tracestate::parse(" a=1 ,\tb=2\t").unwrap()
  assert_eq(ts.to_header(), "a=1,b=2")
}

test "tracestate_parse_rejects_invalid_values" {
  assert_true(@propagation.Tracestate::parse("") is None)
  assert_true(@propagation.Tracestate::parse("a") is None)
  assert_true(@propagation.Tracestate::parse("a=") is None)
  assert_true(@propagation.Tracestate::parse("=1") is None)
  assert_true(@propagation.Tracestate::parse("A=1") is None)
  assert_true(@propagation.Tracestate::parse("a=1,") is None)
  assert_true(@propagation.Tracestate::parse("a=1,,b=2") is None)
}

test "tracestate_parse_rejects_duplicate_keys" {
  assert_true(@propagation.Tracestate::parse("a=1,a=2") is None)
  assert_true(@propagation.Tracestate::parse("a=1,b=2,b=3") is None)
}

test "tracestate_parse_rejects_more_than_32_members" {
  let sb = StringBuilder()
  for i = 0; i < 33; i = i + 1 {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_string("k\{i}=v")
  }
  assert_true(@propagation.Tracestate::parse(sb.to_string()) is None)
}

test "tracestate_parse_or_empty" {
  assert_eq(@propagation.Tracestate::parse_or_empty("").length(), 0)
  assert_eq(@propagation.Tracestate::parse_or_empty("a=").length(), 0)
  assert_eq(@propagation.Tracestate::parse_or_empty("a=1").to_header(), "a=1")
}

test "tracestate_add_prepends_and_keeps_order" {
  let ts = @propagation.Tracestate::empty()
  let ts = ts.add("b", "2").add("a", "1")
  assert_eq(ts.to_header(), "a=1,b=2")
}

test "tracestate_add_replaces_existing_key_at_front" {
  let ts = @propagation.Tracestate::parse("a=1,b=2,c=3").unwrap()
  let ts = ts.add("b", "9")
  assert_eq(ts.length(), 3)
  assert_eq(ts.to_header(), "b=9,a=1,c=3")
}

test "tracestate_add_ignores_invalid_members" {
  let ts = @propagation.Tracestate::parse("a=1").unwrap()
  assert_eq(ts.add("A", "2").to_header(), "a=1")
  assert_eq(ts.add("b", "").to_header(), "a=1")
  assert_eq(ts.add("b", "2,3").to_header(), "a=1")
}

test "tracestate_add_drops_rightmost_when_full" {
  let mut ts = @propagation.Tracestate::empty()
  for i = 0; i < @propagation.TRACESTATE_MAX_MEMBERS; i = i + 1 {
    ts = ts.add("k\{i}", "v")
  }
  assert_eq(ts.length(), @propagation.TRACESTATE_MAX_MEMBERS)
  let ts = ts.add("new", "v")
  assert_eq(ts.length(), @propagation.TRACESTATE_MAX_MEMBERS)
  assert_eq(ts.get("new"), Some("v"))
  // The members were prepended in turn, so the right-most one is `k0`.
  assert_eq(ts.get("k0"), None)
  assert_eq(ts.get("k1"), Some("v"))
}

test "tracestate_update_moves_member_to_front" {
  let ts = @propagation.Tracestate::parse("a=1,b=2,c=3").unwrap()
  let ts = ts.update("c", "9")
  assert_eq(ts.to_header(), "c=9,a=1,b=2")
}

test "tracestate_update_absent_key_is_noop" {
  let ts = @propagation.Tracestate::parse("a=1,b=2").unwrap()
  let ts = ts.update("z", "9")
  assert_eq(ts.to_header(), "a=1,b=2")
}

test "tracestate_update_ignores_invalid_members" {
  let ts = @propagation.Tracestate::parse("a=1").unwrap()
  assert_eq(ts.update("a", "").to_header(), "a=1")
  assert_eq(ts.update("A", "2").to_header(), "a=1")
}

test "tracestate_update_stays_within_limit" {
  let mut ts = @propagation.Tracestate::empty()
  for i = 0; i < @propagation.TRACESTATE_MAX_MEMBERS; i = i + 1 {
    ts = ts.add("k\{i}", "v")
  }
  let ts = ts.update("k5", "new")
  assert_eq(ts.length(), @propagation.TRACESTATE_MAX_MEMBERS)
  assert_eq(ts.get("k5"), Some("new"))
  assert_eq(ts.entries()[0], ("k5", "new"))
  // Updating replaces the old member, so the list stays full: the order is
  // the updated member followed by the previous order without `k5`.
  assert_eq(ts.entries()[1], ("k31", "v"))
  assert_eq(ts.entries()[@propagation.TRACESTATE_MAX_MEMBERS - 1], ("k0", "v"))
}

test "tracestate_remove_preserves_order" {
  let ts = @propagation.Tracestate::parse("a=1,b=2,c=3").unwrap()
  let ts = ts.remove("b")
  assert_eq(ts.to_header(), "a=1,c=3")
  assert_eq(ts.length(), 2)
  assert_eq(ts.get("b"), None)
}

test "tracestate_remove_absent_key_is_noop" {
  let ts = @propagation.Tracestate::parse("a=1").unwrap()
  assert_eq(ts.remove("z").to_header(), "a=1")
  assert_eq(@propagation.Tracestate::empty().remove("z").length(), 0)
}

test "tracestate_mutations_are_immutable" {
  let ts = @propagation.Tracestate::parse("a=1,b=2").unwrap()
  let added = ts.add("c", "3")
  let updated = ts.update("a", "9")
  let removed = ts.remove("a")
  assert_eq(ts.to_header(), "a=1,b=2")
  assert_eq(added.to_header(), "c=3,a=1,b=2")
  assert_eq(updated.to_header(), "a=9,b=2")
  assert_eq(removed.to_header(), "b=2")
}

test "tracestate_entries_returns_a_copy" {
  let ts = @propagation.Tracestate::parse("a=1").unwrap()
  let entries = ts.entries()
  entries.push(("b", "2"))
  assert_eq(ts.to_header(), "a=1")
}

test "parse_traceparent_marks_context_remote" {
  let sc = @propagation.parse_traceparent(
    "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  ).unwrap()
  assert_true(sc.is_remote())
}

test "extract_marks_context_remote_and_keeps_tracestate" {
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set(
    "traceparent",
    "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  )
  carrier.set("tracestate", "vendor=value")
  let sc = @propagation.extract(carrier).unwrap()
  assert_true(sc.is_remote())
  assert_eq(sc.tracestate(), "vendor=value")
}
