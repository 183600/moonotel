// Tests that `defer` statements run when an awaited async call raises. This
// is the guarantee the scoped helpers (`Tracer::with_span_async`,
// `async_runtime.spawn`, ...) rely on to end spans and restore the previous
// context on the error path.

///|
async fn scoped_runner(f : async () -> Unit) -> Unit {
  let previous = @context.attach(
    @context.Context::root().with_value("scoped_runner", "on"),
  )
  defer @context.detach(previous)
  f()
}

///|
async test "defer runs when an awaited async call raises" {
  let caught : Ref[Bool] = Ref(false)
  scoped_runner(() => {
    @async.sleep(1)
    fail("boom")
  }) catch {
    _ => caught.val = true
  }
  assert_true(caught.val)
  assert_eq(@context.current_context().value("scoped_runner"), None)
}
