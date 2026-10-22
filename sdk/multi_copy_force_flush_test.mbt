// A child added to a `MultiSpanProcessor` copy starts out unshut-down. Even
// when another copy set the shared shutdown marker, a force flush on the copy
// must still reach that child.

///|
struct MultiCopyFlushChild {
  name : String
  log : Ref[Array[String]]
}

///|
fn multi_copy_flush_child(
  name : String,
  log : Ref[Array[String]],
) -> MultiCopyFlushChild {
  { name, log }
}

///|
pub impl SpanProcessor for MultiCopyFlushChild with fn on_start(self, _span) {
  let _ = self
}

///|
pub impl SpanProcessor for MultiCopyFlushChild with fn on_end(self, _data) {
  let _ = self
}

///|
pub impl SpanProcessor for MultiCopyFlushChild with fn force_flush(self) {
  self.log.val.push(self.name + ":flush")
}

///|
pub impl SpanProcessor for MultiCopyFlushChild with fn drain_before_shutdown(
  self,
) {
  self.log.val.push(self.name + ":drain")
}

///|
pub impl SpanProcessor for MultiCopyFlushChild with fn shutdown(self) {
  self.log.val.push(self.name + ":shutdown")
}

///|
pub extend MultiCopyFlushChild with SpanProcessor::{
  on_start,
  on_end,
  force_flush,
  drain_before_shutdown,
  is_draining,
  shutdown,
}

///|
test "multi_copy_force_flush_reaches_a_child_added_to_the_copy" {
  let log : Ref[Array[String]] = Ref([])
  let multi = @sdk.MultiSpanProcessor::new(processors=[
    multi_copy_flush_child("a", log),
  ])
  let copy = multi.with_processor(multi_copy_flush_child("b", log))
  multi.shutdown()
  assert_true(copy.is_shutdown())
  assert_eq(log.val, ["a:drain", "a:shutdown"])
  copy.force_flush()
  assert_eq(log.val, ["a:drain", "a:shutdown", "b:flush"])
  copy.shutdown()
  assert_eq(log.val, [
    "a:drain", "a:shutdown", "b:flush", "b:drain", "b:shutdown",
  ])
}
