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

// Attach tokens that still need to be detached, paired with the backend that
// served the matching `attach`. Each token is a distinct copy of the previous
// `Context` value, so two attaches that started from equal values still have
// distinguishable tokens; remembering the backend here lets `detach` restore
// through that backend even if `set_context_storage` swapped the process-wide
// backend in between (the same hazard `with_context` guards against).
let pending_attachments : Array[(Context, ContextStorage)] = []

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
  let backend = storage.val
  let previous = (backend.current)()
  (backend.set)(context)
  // The token is a distinct copy of the previous context. Several logical
  // flows can attach from the same context value (for example two backends
  // that both currently hold `Context::root()`), so matching on the value
  // alone would route `detach` through the wrong backend. `physical_equal`
  // identifies the exact attachment returned by this call.
  let token = { ..previous }
  pending_attachments.push((token, backend))
  token
}

// Restore the context that was current before the matching `attach`. The
// restore is routed through the backend that served `attach`, so a scoped
// context cannot remain installed in that backend when the process-wide
// backend was swapped in between. A token with no outstanding attachment (for
// example because `detach` is called twice) falls back to the current backend.

///|
pub fn detach(previous : Context) -> Unit {
  let mut found = pending_attachments.length() - 1
  while found >= 0 {
    if physical_equal(pending_attachments.unsafe_get(found).0, previous) {
      break
    }
    found = found - 1
  }
  if found >= 0 {
    let (_, backend) = pending_attachments.remove(found)
    (backend.set)(previous)
  } else {
    (storage.val.set)(previous)
  }
}

// Run `f` with `context` as the current context and restore the previous
// context afterwards, even if `f` raises.

///|
pub fn[X] with_context(context : Context, f : () -> X raise?) -> X raise? {
  // Capture the backend that receives the scoped context. If `f` installs a
  // different backend, restoring through the *current* backend would leave the
  // captured backend holding the scoped context forever.
  let backend = storage.val
  let previous = (backend.current)()
  (backend.set)(context)
  defer (backend.set)(previous)
  f()
}

// The current span context, if the current context carries one.

///|
pub fn current_span_context() -> @api.SpanContext? {
  current_context().span_context()
}

// Run `f` with `sc` attached as the current span context. The rest of the
// current context (for example baggage values) stays visible inside `f`.

///|
pub fn[X] with_span_context(
  sc : @api.SpanContext,
  f : () -> X raise?,
) -> X raise? {
  with_context(current_context().with_span(sc), f)
}
