// `with_context` must restore the previous context through the backend that was
// active when the scope was entered, even when the scoped code swaps the
// process-wide storage backend.

///|
fn audit_backend(
  slot : Ref[String],
  root : String,
) -> @context.ContextStorage {
  {
    current: () => @context.Context::root().with_value("backend", slot.val),
    set: context => {
      slot.val = match context.value("backend") {
        Some(value) => value
        None => root
      }
    },
  }
}

///|
test "with_context_restores_the_backend_captured_at_attach" {
  let slot_a : Ref[String] = Ref("A-root")
  let slot_b : Ref[String] = Ref("B-root")
  let backend_a = audit_backend(slot_a, "A-root")
  let backend_b = audit_backend(slot_b, "B-root")
  let original = @context.set_context_storage(backend_a)
  defer @context.set_context_storage(original) |> ignore
  @context.with_context(
    @context.Context::root().with_value("backend", "A-inner"),
    () => {
      let _ = @context.set_context_storage(backend_b)
      assert_eq(@context.current_context().value("backend"), Some("B-root"))
    },
  )
  // Restoring into the *current* backend would leave A holding the scoped
  // value forever.
  assert_eq(slot_a.val, "A-root")
}
