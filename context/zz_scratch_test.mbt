test "scratch_has_baggage_true_when_value_present" {
  let ctx = @context.Context::root().with_value("a", "1")
  assert_true(ctx.has_baggage())
  assert_eq(ctx.baggage().get("a"), Some("1"))
}

test "scratch_has_baggage_false_when_removed" {
  let ctx = @context.Context::root().with_value("a", "1").without_value("a")
  assert_false(ctx.has_baggage())
  assert_eq(ctx.baggage().get("a"), None)
}

test "scratch_has_baggage_removed_then_readded" {
  let ctx = @context.Context::root()
    .with_value("a", "1")
    .without_value("a")
    .with_value("a", "2")
  assert_true(ctx.has_baggage())
  assert_eq(ctx.baggage().get("a"), Some("2"))
}

test "scratch_baggage_multiple_removed" {
  let ctx = @context.Context::root()
    .with_value("a", "1")
    .with_value("b", "2")
    .without_value("a")
    .without_value("b")
  assert_false(ctx.has_baggage())
  assert_eq(ctx.baggage().length(), 0)
}

test "scratch_baggage_removal_of_missing_key" {
  let ctx = @context.Context::root().with_value("a", "1").without_value("b")
  assert_true(ctx.has_baggage())
  assert_eq(ctx.baggage().get("a"), Some("1"))
  assert_eq(ctx.baggage().get("b"), None)
}

test "scratch_baggage_last_removal_wins" {
  let ctx = @context.Context::root()
    .with_value("a", "1")
    .without_value("a")
    .with_value("a", "2")
    .without_value("a")
  assert_false(ctx.has_baggage())
  assert_eq(ctx.baggage().get("a"), None)
}

test "scratch_with_baggage_applies_all" {
  let values : Map[String, String] = Map([])
  values.set("x", "1")
  values.set("y", "2")
  let ctx = @context.Context::root().with_baggage(values)
  assert_eq(ctx.baggage().get("x"), Some("1"))
  assert_eq(ctx.baggage().get("y"), Some("2"))
}

test "scratch_attach_detach_restores" {
  let saved = @context.current_context()
  let token = @context.attach(@context.Context::root().with_value("k", "v"))
  assert_eq(@context.current_context().value("k"), Some("v"))
  @context.detach(token)
  assert_eq(@context.current_context().value("k"), saved.value("k"))
}

test "scratch_with_context_restores_on_raise" {
  let before = @context.current_context()
  let result = try {
    @context.with_context(
      @context.Context::root().with_value("k", "v"),
      () => {
        assert_eq(@context.current_context().value("k"), Some("v"))
        raise Failure("boom")
      },
    )
    Ok(())
  } catch {
    error => Err(error)
  }
  assert_eq(@context.current_context().value("k"), before.value("k"))
  match result {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}
