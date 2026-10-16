// Blackbox tests for immutable Context and the context storage.

fn span_context_a() -> @api.SpanContext {
  @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    1,
  )
}

fn span_context_b() -> @api.SpanContext {
  @api.span_context(
    @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @api.bytes_from_hex("0000000000000001").unwrap(),
    0,
  )
}

test "root_context_is_empty" {
  let root = @context.Context::root()
  assert_true(root.span_context() is None)
  assert_eq(root.value("missing"), None)
  assert_eq(root.baggage().length(), 0)
  assert_true(root.parent() is None)
}

test "with_span_is_immutable" {
  let root = @context.Context::root()
  let derived = root.with_span(span_context_a())
  assert_true(root.span_context() is None)
  assert_true(derived.span_context() is Some(_))
  assert_eq(derived.span_context().unwrap().span_id_hex(), "00f067aa0ba902b7")
}

test "inner_span_shadows_outer" {
  let root = @context.Context::root()
  let outer = root.with_span(span_context_a())
  let inner = outer.with_span(span_context_b())
  assert_eq(inner.span_context().unwrap().span_id_hex(), "0000000000000001")
  assert_eq(outer.span_context().unwrap().span_id_hex(), "00f067aa0ba902b7")
}

test "baggage_inheritance_and_override" {
  let root = @context.Context::root()
  let with_user = root.with_value("user.id", "42").with_value("tenant", "acme")
  let override = with_user.with_value("tenant", "beta")
  assert_eq(override.value("user.id"), Some("42"))
  assert_eq(override.value("tenant"), Some("beta"))
  assert_eq(with_user.value("tenant"), Some("acme"))
  let baggage = override.baggage()
  assert_eq(baggage.length(), 2)
  assert_eq(baggage.get("tenant"), Some("beta"))
  assert_eq(baggage.get("user.id"), Some("42"))
}

test "baggage_and_span_coexist" {
  let ctx = @context.Context::root()
    .with_value("k", "v")
    .with_span(span_context_a())
  assert_eq(ctx.value("k"), Some("v"))
  assert_true(ctx.span_context() is Some(_))
}

test "storage_defaults_to_root" {
  assert_true(@context.current_context().span_context() is None)
  assert_true(@context.current_span_context() is None)
}

test "attach_and_detach" {
  let previous = @context.attach(@context.Context::root().with_span(span_context_a()))
  assert_true(@context.current_span_context() is Some(_))
  @context.detach(previous)
  assert_true(@context.current_span_context() is None)
}

test "with_context_scopes_nested_blocks" {
  let outer = @context.Context::root().with_span(span_context_a())
  let inner = @context.Context::root().with_span(span_context_b())
  @context.with_context(outer, fn() {
    assert_eq(
      @context.current_span_context().unwrap().span_id_hex(),
      "00f067aa0ba902b7",
    )
    @context.with_context(inner, fn() {
      assert_eq(
        @context.current_span_context().unwrap().span_id_hex(),
        "0000000000000001",
      )
    })
    assert_eq(
      @context.current_span_context().unwrap().span_id_hex(),
      "00f067aa0ba902b7",
    )
  })
  assert_true(@context.current_span_context() is None)
}

test "with_span_context_helper" {
  @context.with_span_context(span_context_a(), fn() {
    assert_eq(
      @context.current_span_context().unwrap().trace_id_hex(),
      "4bf92f359d1e75b7618a2d1f3c4e5a6b",
    )
  })
  assert_true(@context.current_span_context() is None)
}
