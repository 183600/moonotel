// `detach` must restore through the backend that served the matching
// `attach`, even when the process-wide storage backend is swapped in between.

///|
fn attach_detach_backend(
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
test "detach_restores_the_backend_captured_at_attach" {
  let slot_a : Ref[String] = Ref("A-root")
  let slot_b : Ref[String] = Ref("B-root")
  let backend_a = attach_detach_backend(slot_a, "A-root")
  let backend_b = attach_detach_backend(slot_b, "B-root")
  let original = @context.set_context_storage(backend_a)
  defer @context.set_context_storage(original) |> ignore
  let token = @context.attach(
    @context.Context::root().with_value("backend", "A-inner"),
  )
  let _ = @context.set_context_storage(backend_b)
  @context.detach(token)
  let _ = @context.set_context_storage(backend_a)
  // Restoring through the current backend would leave A holding the scoped
  // value forever.
  assert_eq(slot_a.val, "A-root")
}
