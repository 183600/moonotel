// Two storage backends may both hold the same previous context value. Each
// `attach` must still return a token that routes `detach` through the backend
// that served that exact attach, not through whichever backend happens to be
// current when the token is detached.

///|
fn root_token_backend(slot : Ref[String], root : String) -> @context.ContextStorage {
  {
    current: () => @context.Context::root(),
    set: context => {
      slot.val = match context.value("backend") {
        Some(value) => value
        None => root
      }
    },
  }
}

///|
test "detach_routes_equal_tokens_through_their_own_backend" {
  let slot_a : Ref[String] = Ref("A-root")
  let slot_b : Ref[String] = Ref("B-root")
  let backend_a = root_token_backend(slot_a, "A-root")
  let backend_b = root_token_backend(slot_b, "B-root")
  let original = @context.set_context_storage(backend_a)
  defer @context.set_context_storage(original) |> ignore
  let token_a = @context.attach(
    @context.Context::root().with_value("backend", "A-inner"),
  )
  let _ = @context.set_context_storage(backend_b)
  let token_b = @context.attach(
    @context.Context::root().with_value("backend", "B-inner"),
  )
  // Both tokens represent `Context::root()` before their attach. Detaching the
  // first token must restore backend A without touching backend B.
  @context.detach(token_a)
  assert_eq(slot_a.val, "A-root")
  assert_eq(slot_b.val, "B-inner")
  @context.detach(token_b)
  assert_eq(slot_b.val, "B-root")
}
