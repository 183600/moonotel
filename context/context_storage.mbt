// Scoped "current context" storage.
//
// The storage keeps a stack of contexts for the current execution flow.
// `with_context` scopes a context to a function call; `attach`/`detach` allow
// manual scoping. Note: the stack is process-global, so for concurrent tasks
// prefer passing contexts explicitly and only rely on the storage within a
// single logical flow.

let context_stack : Ref[Array[Context]] = Ref([])

// The context at the top of the stack, or an empty root context.
pub fn current_context() -> Context {
  let stack = context_stack.val
  if stack.length() == 0 {
    Context::root()
  } else {
    stack[stack.length() - 1]
  }
}

// Push a context, returning the previous top of the stack.
pub fn attach(context : Context) -> Context {
  let stack = context_stack.val
  let previous = if stack.length() == 0 {
    Context::root()
  } else {
    stack[stack.length() - 1]
  }
  stack.push(context)
  previous
}

// Restore the top of the stack to `previous`.
pub fn detach(previous : Context) -> Unit {
  let stack = context_stack.val
  if stack.length() > 0 {
    let _ = stack.pop()
  }
  let _ = previous
}

// Run `f` with `context` as the current context and restore the previous
// context afterwards, even if `f` raises.
pub fn[X] with_context(context : Context, f : () -> X raise?) -> X raise? {
  let previous = attach(context)
  defer detach(previous)
  f()
}

// The current span context, if the current context carries one.
pub fn current_span_context() -> @api.SpanContext? {
  current_context().span_context()
}

// Run `f` with `sc` attached as the current span context.
pub fn[X] with_span_context(sc : @api.SpanContext, f : () -> X raise?) -> X raise? {
  with_context(Context::root().with_span(sc), f)
}
