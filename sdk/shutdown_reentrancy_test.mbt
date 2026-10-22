// Shutdown must stay idempotent when a processor or exporter calls back into
// the provider or multi-processor that is currently shutting it down.

///|
struct ProviderReenteringProcessor {
  provider : Ref[@sdk.TracerProviderSdk?]
  drains : Ref[Int32]
  shutdowns : Ref[Int32]
}

///|
pub impl @sdk.SpanProcessor for ProviderReenteringProcessor with fn on_start(
  self,
  _span,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for ProviderReenteringProcessor with fn on_end(
  self,
  _data,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for ProviderReenteringProcessor with fn force_flush(
  self,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for ProviderReenteringProcessor with fn drain_before_shutdown(
  self,
) {
  self.drains.val = self.drains.val + 1
  match self.provider.val {
    Some(provider) => provider.shutdown()
    None => ()
  }
}

///|
pub impl @sdk.SpanProcessor for ProviderReenteringProcessor with fn shutdown(
  self,
) {
  self.shutdowns.val = self.shutdowns.val + 1
}

///|
test "provider shutdown tolerates a processor reentering it while draining" {
  let processor : ProviderReenteringProcessor = {
    provider: Ref(None),
    drains: Ref(0),
    shutdowns: Ref(0),
  }
  let provider = @sdk.TracerProviderSdk::new(service_name="reentrant").with_span_processor(
    processor,
  )
  processor.provider.val = Some(provider)
  provider.shutdown()
  assert_eq(processor.drains.val, 1)
  assert_eq(processor.shutdowns.val, 1)
  assert_true(provider.is_shutdown())
}

///|
struct MultiReenteringProcessor {
  multi : Ref[@sdk.MultiSpanProcessor?]
  drains : Ref[Int32]
  shutdowns : Ref[Int32]
}

///|
pub impl @sdk.SpanProcessor for MultiReenteringProcessor with fn on_start(
  self,
  _span,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for MultiReenteringProcessor with fn on_end(
  self,
  _data,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for MultiReenteringProcessor with fn force_flush(
  self,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for MultiReenteringProcessor with fn drain_before_shutdown(
  self,
) {
  self.drains.val = self.drains.val + 1
  match self.multi.val {
    Some(multi) => multi.shutdown()
    None => ()
  }
}

///|
pub impl @sdk.SpanProcessor for MultiReenteringProcessor with fn shutdown(
  self,
) {
  self.shutdowns.val = self.shutdowns.val + 1
}

///|
test "multi processor shutdown tolerates a child reentering it while draining" {
  let processor : MultiReenteringProcessor = {
    multi: Ref(None),
    drains: Ref(0),
    shutdowns: Ref(0),
  }
  let multi = @sdk.MultiSpanProcessor::new(processors=[processor])
  processor.multi.val = Some(multi)
  multi.shutdown()
  assert_eq(processor.drains.val, 1)
  assert_eq(processor.shutdowns.val, 1)
  assert_true(multi.is_shutdown())
}
