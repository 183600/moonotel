// A force flush requested while a processor set is draining belongs to the
// shutdown sequence. It must not re-enter the children: `shutdown` already
// owns the queue and exporter close order.

///|
struct FlushDuringDrainProcessor {
  flushes : Ref[Int32]
  on_drain : () -> Unit
}

///|
fn flush_during_drain_processor(
  on_drain : () -> Unit,
) -> FlushDuringDrainProcessor {
  { flushes: Ref(0), on_drain, }
}

///|
pub impl SpanProcessor for FlushDuringDrainProcessor with fn on_start(
  self,
  _span,
) {
  let _ = self
}

///|
pub impl SpanProcessor for FlushDuringDrainProcessor with fn on_end(self, _data) {
  let _ = self
}

///|
pub impl SpanProcessor for FlushDuringDrainProcessor with fn force_flush(self) {
  self.flushes.val = self.flushes.val + 1
}

///|
pub impl SpanProcessor for FlushDuringDrainProcessor with fn drain_before_shutdown(
  self,
) {
  (self.on_drain)()
}

///|
pub impl SpanProcessor for FlushDuringDrainProcessor with fn shutdown(self) {
  let _ = self
}

///|
pub extend FlushDuringDrainProcessor with SpanProcessor::{
  on_start,
  on_end,
  force_flush,
  drain_before_shutdown,
  is_draining,
  shutdown,
}

///|
test "provider_force_flush_during_shutdown_drain_is_ignored" {
  let provider_ref : Ref[@sdk.TracerProviderSdk?] = Ref(None)
  let first = flush_during_drain_processor(() => {
    match provider_ref.val {
      Some(provider) => provider.force_flush()
      None => ()
    }
  })
  let second = flush_during_drain_processor(() => ())
  let provider = @sdk.TracerProviderSdk::new(
    service_name="provider-flush-during-drain",
  ).with_span_processors([first, second])
  provider_ref.val = Some(provider)
  provider.shutdown()
  assert_true(provider.is_shutdown())
  assert_eq(first.flushes.val, 0)
  assert_eq(second.flushes.val, 0)
}

///|
test "multi_force_flush_during_shutdown_drain_is_ignored" {
  let multi_ref : Ref[@sdk.MultiSpanProcessor?] = Ref(None)
  let first = flush_during_drain_processor(() => {
    match multi_ref.val {
      Some(multi) => multi.force_flush()
      None => ()
    }
  })
  let second = flush_during_drain_processor(() => ())
  let multi = @sdk.MultiSpanProcessor::new(processors=[first, second])
  multi_ref.val = Some(multi)
  multi.drain_before_shutdown()
  assert_eq(first.flushes.val, 0)
  assert_eq(second.flushes.val, 0)
  multi.shutdown()
  assert_true(multi.is_shutdown())
  assert_eq(first.flushes.val, 0)
  assert_eq(second.flushes.val, 0)
}
