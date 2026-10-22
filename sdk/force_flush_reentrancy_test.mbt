// A force flush that reaches a shutdown must stop calling the remaining
// processors: `shutdown` has already drained and closed them.

///|
struct ReentrantFlushProcessor {
  flushes : Ref[Int32]
  shutdowns : Ref[Int32]
  on_flush : (() -> Unit)?
}

///|
pub impl @sdk.SpanProcessor for ReentrantFlushProcessor with fn on_start(
  self,
  _span,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for ReentrantFlushProcessor with fn on_end(
  self,
  _data,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for ReentrantFlushProcessor with fn force_flush(
  self,
) {
  self.flushes.val = self.flushes.val + 1
  match self.on_flush {
    Some(callback) => callback()
    None => ()
  }
}

///|
pub impl @sdk.SpanProcessor for ReentrantFlushProcessor with fn shutdown(self) {
  self.shutdowns.val = self.shutdowns.val + 1
}

///|
pub extend ReentrantFlushProcessor with @sdk.SpanProcessor::{
  on_start,
  on_end,
  force_flush,
  is_draining,
  shutdown,
}

///|
fn reentrant_flush_processor(
  on_flush? : () -> Unit,
) -> ReentrantFlushProcessor {
  {
    flushes: Ref(0),
    shutdowns: Ref(0),
    on_flush: match on_flush {
      Some(callback) => Some(callback)
      None => None
    },
  }
}

///|
test "provider_force_flush_stops_after_a_reentrant_shutdown" {
  let provider_ref : Ref[@sdk.TracerProviderSdk?] = Ref(None)
  let first = reentrant_flush_processor(on_flush=() => {
    match provider_ref.val {
      Some(provider) => provider.shutdown()
      None => ()
    }
  })
  let second = reentrant_flush_processor()
  let provider = @sdk.TracerProviderSdk::new(service_name="flush-reentrant")
    .with_span_processors([first, second])
  provider_ref.val = Some(provider)
  provider.force_flush()
  assert_eq(first.flushes.val, 1)
  assert_eq(second.flushes.val, 0)
  assert_eq(first.shutdowns.val, 1)
  assert_eq(second.shutdowns.val, 1)
  provider.force_flush()
  assert_eq(first.flushes.val, 1)
  assert_eq(second.flushes.val, 0)
}

///|
test "multi_processor_force_flush_stops_after_a_reentrant_shutdown" {
  let multi_ref : Ref[@sdk.MultiSpanProcessor?] = Ref(None)
  let first = reentrant_flush_processor(on_flush=() => {
    match multi_ref.val {
      Some(multi) => multi.shutdown()
      None => ()
    }
  })
  let second = reentrant_flush_processor()
  let multi = @sdk.MultiSpanProcessor::new(processors=[first, second])
  multi_ref.val = Some(multi)
  multi.force_flush()
  assert_eq(first.flushes.val, 1)
  assert_eq(second.flushes.val, 0)
  assert_eq(first.shutdowns.val, 1)
  assert_eq(second.shutdowns.val, 1)
  multi.force_flush()
  assert_eq(first.flushes.val, 1)
  assert_eq(second.flushes.val, 0)
}

///|
test "provider_force_flush_is_not_reentered_by_a_processor" {
  let provider_ref : Ref[@sdk.TracerProviderSdk?] = Ref(None)
  let nested : Ref[Int32] = Ref(0)
  let first = reentrant_flush_processor(on_flush=() => {
    // Bound the probe so a missing guard fails as an assertion instead of
    // recursing forever.
    if nested.val < 3 {
      nested.val = nested.val + 1
      match provider_ref.val {
        Some(provider) => provider.force_flush()
        None => ()
      }
    }
  })
  let second = reentrant_flush_processor()
  let provider = @sdk.TracerProviderSdk::new(service_name="flush-nested")
    .with_span_processors([first, second])
  provider_ref.val = Some(provider)
  provider.force_flush()
  assert_eq(nested.val, 1)
  assert_eq(first.flushes.val, 1)
  assert_eq(second.flushes.val, 1)
}

///|
test "multi_processor_force_flush_is_not_reentered_by_a_child" {
  let multi_ref : Ref[@sdk.MultiSpanProcessor?] = Ref(None)
  let nested : Ref[Int32] = Ref(0)
  let first = reentrant_flush_processor(on_flush=() => {
    if nested.val < 3 {
      nested.val = nested.val + 1
      match multi_ref.val {
        Some(multi) => multi.force_flush()
        None => ()
      }
    }
  })
  let second = reentrant_flush_processor()
  let multi = @sdk.MultiSpanProcessor::new(processors=[first, second])
  multi_ref.val = Some(multi)
  multi.force_flush()
  assert_eq(nested.val, 1)
  assert_eq(first.flushes.val, 1)
  assert_eq(second.flushes.val, 1)
}
