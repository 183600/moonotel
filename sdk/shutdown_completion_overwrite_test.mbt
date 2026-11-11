///|
struct CompletionOverwriteExporter {
  first : Ref[@sdk.TracerProviderSdk?]
  second : Ref[@sdk.TracerProviderSdk?]
  mut reenter : Bool
}

///|
pub impl @sdk.SpanExporter for CompletionOverwriteExporter with fn export_spans(
  self,
  spans,
) {
  let _ = spans
  if self.reenter {
    self.reenter = false
    match self.first.val {
      Some(provider) => provider.shutdown()
      None => ()
    }
    match self.second.val {
      Some(provider) => provider.shutdown()
      None => ()
    }
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for CompletionOverwriteExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
struct CompletionOverwriteProcessor {
  shutdowns : Ref[Int32]
}

///|
pub impl @sdk.SpanProcessor for CompletionOverwriteProcessor with fn on_start(
  self,
  span,
) {
  let _ = self
  let _ = span
}

///|
pub impl @sdk.SpanProcessor for CompletionOverwriteProcessor with fn on_end(
  self,
  data,
) {
  let _ = self
  let _ = data
}

///|
pub impl @sdk.SpanProcessor for CompletionOverwriteProcessor with fn force_flush(
  self,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CompletionOverwriteProcessor with fn shutdown(
  self,
) {
  self.shutdowns.val = self.shutdowns.val + 1
}

///|
struct CompletionOverwriteTrigger {
  first : Ref[@sdk.TracerProviderSdk?]
  second : Ref[@sdk.TracerProviderSdk?]
}

///|
pub impl @sdk.SpanProcessor for CompletionOverwriteTrigger with fn on_start(
  self,
  span,
) {
  let _ = self
  let _ = span
}

///|
pub impl @sdk.SpanProcessor for CompletionOverwriteTrigger with fn on_end(
  self,
  data,
) {
  let _ = self
  let _ = data
}

///|
pub impl @sdk.SpanProcessor for CompletionOverwriteTrigger with fn force_flush(
  self,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CompletionOverwriteTrigger with fn drain_before_shutdown(
  self,
) {
  match self.first.val {
    Some(provider) => provider.shutdown()
    None => ()
  }
  match self.second.val {
    Some(provider) => provider.shutdown()
    None => ()
  }
}

///|
pub impl @sdk.SpanProcessor for CompletionOverwriteTrigger with fn shutdown(
  self,
) {
  let _ = self
}

///|
test "shutdown completions from multiple providers are all run" {
  let exporter : CompletionOverwriteExporter = {
    first: Ref(None),
    second: Ref(None),
    reenter: true,
  }
  let batch = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=10,
    max_export_batch_size=10,
    flush_interval_millis=1000000,
  )
  let first_extra = CompletionOverwriteProcessor::{ shutdowns: Ref(0), }
  let second_extra = CompletionOverwriteProcessor::{ shutdowns: Ref(0), }
  let first = @sdk.TracerProviderSdk::new(
      service_name="completion-overwrite-first",
    )
    .with_span_processors([batch, first_extra])
    .with_sampler(@sdk.Sampler::always_on())
  let second = @sdk.TracerProviderSdk::new(
      service_name="completion-overwrite-second",
    )
    .with_span_processors([batch, second_extra])
    .with_sampler(@sdk.Sampler::always_on())
  exporter.first.val = Some(first)
  exporter.second.val = Some(second)
  batch.on_end(probe_span("s0"))
  batch.drain_before_shutdown()
  assert_eq(first_extra.shutdowns.val, 1)
  assert_eq(second_extra.shutdowns.val, 1)
  assert_true(first.is_shutdown())
  assert_true(second.is_shutdown())
}

///|
test "multi processor runs shutdown completions from multiple providers" {
  let trigger : CompletionOverwriteTrigger = {
    first: Ref(None),
    second: Ref(None),
  }
  let multi = @sdk.MultiSpanProcessor::new(processors=[trigger])
  let first_extra = CompletionOverwriteProcessor::{ shutdowns: Ref(0), }
  let second_extra = CompletionOverwriteProcessor::{ shutdowns: Ref(0), }
  let first = @sdk.TracerProviderSdk::new(
      service_name="completion-overwrite-multi-first",
    )
    .with_span_processors([multi, first_extra])
    .with_sampler(@sdk.Sampler::always_on())
  let second = @sdk.TracerProviderSdk::new(
      service_name="completion-overwrite-multi-second",
    )
    .with_span_processors([multi, second_extra])
    .with_sampler(@sdk.Sampler::always_on())
  trigger.first.val = Some(first)
  trigger.second.val = Some(second)
  multi.drain_before_shutdown()
  assert_eq(first_extra.shutdowns.val, 1)
  assert_eq(second_extra.shutdowns.val, 1)
  assert_true(first.is_shutdown())
  assert_true(second.is_shutdown())
}
