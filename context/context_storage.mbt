// Scoped "current context" storage.
//
// The storage keeps the context of the current execution flow.
// `with_context` scopes a context to a function call; `attach`/`detach` allow
// manual scoping. The default storage is a single process-global slot, which
// is correct for synchronous, single-flow programs. Inside concurrent tasks,
// hoist contexts into function parameters (the instrumentation does this)
// instead of relying on the ambient context. Runtime integrations that can
// scope the current context to a logical flow (for example an event loop with
// scheduler hooks) can swap in their own backend via `set_context_storage`.

// Pluggable storage backend for the current context.
///|
pub(all) struct ContextStorage {
  current : () -> Context
  set : (Context) -> Unit
}

///|
let global_slot : Ref[Context] = Ref(Context::root())

///|
fn global_current() -> Context {
  global_slot.val
}

///|
fn global_set(context : Context) -> Unit {
  global_slot.val = context
}

///|
let storage : Ref[ContextStorage] = Ref({
  current: global_current,
  set: global_set,
})

// Replace the storage backend and return the previous one (pass it back to
// restore the default behavior). Intended for runtime integrations that can
// scope the current context to a logical flow.

///|
pub fn set_context_storage(new_storage : ContextStorage) -> ContextStorage {
  let previous = storage.val
  storage.val = new_storage
  previous
}

// The context of the current execution flow, or an empty root context.

///|
pub fn current_context() -> Context {
  (storage.val.current)()
}

// Install `context` as the current context and return the context that was
// current before; pass the result to `detach` to restore it.

///|
pub fn attach(context : Context) -> Context {
  let previous = current_context()
  (storage.val.set)(context)
  previous
}

// Restore the context that was current before the matching `attach`.

///|
pub fn detach(previous : Context) -> Unit {
  (storage.val.set)(previous)
}

// Run `f` with `context` as the current context and restore the previous
// context afterwards, even if `f` raises.

///|
pub fn[X] with_context(context : Context, f : () -> X raise?) -> X raise? {
  let previous = attach(context)
  defer detach(previous)
  f()
}

// The current span context, if the current context carries one.

///|
pub fn current_span_context() -> @api.SpanContext? {
  current_context().span_context()
}

// Run `f` with `sc` attached as the current span context.

///|
pub fn[X] with_span_context(
  sc : @api.SpanContext,
  f : () -> X raise?,
) -> X raise? {
  with_context(Context::root().with_span(sc), f)
}
