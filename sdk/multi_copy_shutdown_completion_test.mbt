///|
struct MultiCopyCompletionProcessor {
  provider : Ref[@sdk.TracerProviderSdk?]
  drains : Ref[Int32]
  shutdowns : Ref[Int32]
}

///|
pub impl @sdk.SpanProcessor for MultiCopyCompletionProcessor with fn on_start(
  self,
  span,
) {
  let _ = self
  let _ = span
}

///|
pub impl @sdk.SpanProcessor for MultiCopyCompletionProcessor with fn on_end(
  self,
  data,
) {
  let _ = self
  let _ = data
}

///|
pub impl @sdk.SpanProcessor for MultiCopyCompletionProcessor with fn force_flush(
  self,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for MultiCopyCompletionProcessor with fn drain_before_shutdown(
  self,
) {
  self.drains.val = self.drains.val + 1
  match self.provider.val {
    Some(provider) => provider.shutdown()
    None => ()
  }
}

///|
pub impl @sdk.SpanProcessor for MultiCopyCompletionProcessor with fn shutdown(
  self,
) {
  self.shutdowns.val = self.shutdowns.val + 1
}

///|
fn multi_copy_completion_processor(
  provider? : @sdk.TracerProviderSdk,
) -> MultiCopyCompletionProcessor {
  { provider: Ref(provider), drains: Ref(0), shutdowns: Ref(0), }
}

///|
test "copy drain runs a shutdown completion set on the original multi" {
  let trigger = multi_copy_completion_processor()
  let copy_child = multi_copy_completion_processor()
  let extra = multi_copy_completion_processor()
  let original = @sdk.MultiSpanProcessor::new(processors=[trigger])
  let copy = original.with_processor(copy_child)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="multi-copy-completion",
  ).with_span_processors([original, extra])
  trigger.provider.val = Some(provider)
  let copy_provider = @sdk.TracerProviderSdk::new(
    service_name="multi-copy-completion-copy",
  ).with_span_processor(copy)
  copy_provider.shutdown()
  assert_eq(trigger.drains.val, 1)
  assert_eq(trigger.shutdowns.val, 1)
  assert_eq(copy_child.drains.val, 1)
  assert_eq(copy_child.shutdowns.val, 1)
  assert_eq(extra.shutdowns.val, 1)
  assert_true(original.is_shutdown())
  assert_true(copy.is_shutdown())
  assert_true(provider.is_shutdown())
  assert_true(copy_provider.is_shutdown())
}

///|
test "copy direct drain runs a shutdown completion set on the original multi" {
  let trigger = multi_copy_completion_processor()
  let copy_child = multi_copy_completion_processor()
  let extra = multi_copy_completion_processor()
  let original = @sdk.MultiSpanProcessor::new(processors=[trigger])
  let copy = original.with_processor(copy_child)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="multi-copy-completion-direct",
  ).with_span_processors([original, extra])
  trigger.provider.val = Some(provider)
  copy.drain_before_shutdown()
  assert_eq(trigger.drains.val, 1)
  assert_eq(trigger.shutdowns.val, 1)
  assert_eq(copy_child.drains.val, 1)
  assert_eq(extra.shutdowns.val, 1)
  assert_true(original.is_shutdown())
  assert_true(provider.is_shutdown())
}
