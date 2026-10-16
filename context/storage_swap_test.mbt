// Tests for the pluggable current-context storage backend.

///|
test "set_context_storage_routes_every_operation_through_the_backend" {
  let slot : Ref[String] = Ref("root")
  let backend : @context.ContextStorage = {
    current: () => @context.Context::root().with_value("backend", slot.val),
    set: context => {
      slot.val = match context.value("backend") {
        Some(value) => value
        None => "<none>"
      }
    },
  }
  let previous = @context.set_context_storage(backend)
  defer @context.set_context_storage(previous) |> ignore
  assert_eq(@context.current_context().value("backend"), Some("root"))
  let before = @context.attach(
    @context.Context::root().with_value("backend", "inner"),
  )
  assert_eq(before.value("backend"), Some("root"))
  assert_eq(@context.current_context().value("backend"), Some("inner"))
  @context.detach(before)
  assert_eq(@context.current_context().value("backend"), Some("root"))
}

///|
test "swapping_storage_back_restores_the_global_slot" {
  let global_before = @context.current_context()
  let backend : @context.ContextStorage = {
    current: () => @context.Context::root().with_value("swapped", "yes"),
    set: _ => (),
  }
  let previous = @context.set_context_storage(backend)
  assert_eq(@context.current_context().value("swapped"), Some("yes"))
  let _ = @context.set_context_storage(previous)
  assert_eq(
    @context.current_context().value("swapped"),
    global_before.value("swapped"),
  )
}

///|
test "detach_restores_the_previous_context_when_tokens_nest" {
  let a = @context.Context::root().with_value("mark", "a")
  let b = @context.Context::root().with_value("mark", "b")
  let outer = @context.attach(a)
  let inner = @context.attach(b)
  assert_eq(@context.current_context().value("mark"), Some("b"))
  @context.detach(inner)
  assert_eq(@context.current_context().value("mark"), Some("a"))
  @context.detach(outer)
  assert_eq(@context.current_context().value("mark"), None)
}

///|
test "detach_is_idempotent_for_repeated_tokens" {
  let saved = @context.current_context()
  let token = @context.attach(@context.Context::root().with_value("k", "v"))
  @context.detach(token)
  @context.detach(token)
  assert_eq(@context.current_context().value("k"), saved.value("k"))
}
