// Reentrant shutdown/flush on a provider copy must still reach the processors
// or children that only that copy owns. The process-wide drain/flush guards
// are shared with copies, but the processor sets are not.

///|
struct CopyShutdownCountingProcessor {
  shutdowns : Ref[Int32]
  flushes : Ref[Int32]
}

///|
pub impl @sdk.SpanProcessor for CopyShutdownCountingProcessor with fn on_start(
  self,
  _span,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CopyShutdownCountingProcessor with fn on_end(
  self,
  _data,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CopyShutdownCountingProcessor with fn force_flush(
  self,
) {
  self.flushes.val = self.flushes.val + 1
}

///|
pub impl @sdk.SpanProcessor for CopyShutdownCountingProcessor with fn shutdown(
  self,
) {
  self.shutdowns.val = self.shutdowns.val + 1
}

///|
pub extend CopyShutdownCountingProcessor with @sdk.SpanProcessor::{
  on_start,
  on_end,
  force_flush,
  is_draining,
  shutdown,
}

///|
struct CopyShutdownCallingExporter {
  copy : Ref[@sdk.TracerProviderSdk?]
}

///|
pub impl @sdk.SpanExporter for CopyShutdownCallingExporter with fn export_spans(
  self,
  _spans,
) {
  let _ = self
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for CopyShutdownCallingExporter with fn shutdown(
  self,
) {
  match self.copy.val {
    Some(copy) => copy.shutdown()
    None => ()
  }
}

///|
test "provider_copy_shutdown_during_another_shutdown_reaches_the_copy" {
  let exporter : CopyShutdownCallingExporter = { copy: Ref(None), }
  let base = @sdk.TracerProviderSdk::new(service_name="copy-shutdown-during")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let extra : CopyShutdownCountingProcessor = {
    shutdowns: Ref(0),
    flushes: Ref(0),
  }
  let copy = base.with_span_processor(extra)
  exporter.copy.val = Some(copy)
  base.shutdown()
  assert_true(copy.is_shutdown())
  assert_eq(extra.shutdowns.val, 1)
}

///|
test "provider_copy_force_flush_during_another_flush_reaches_the_copy" {
  let copy_ref : Ref[@sdk.TracerProviderSdk?] = Ref(None)
  let first = reentrant_flush_processor(on_flush=() => {
    match copy_ref.val {
      Some(copy) => copy.force_flush()
      None => ()
    }
  })
  let second = reentrant_flush_processor()
  let base = @sdk.TracerProviderSdk::new(service_name="copy-flush-during")
    .with_span_processor(first)
  let copy = base.with_span_processor(second)
  copy_ref.val = Some(copy)
  base.force_flush()
  assert_eq(first.flushes.val, 1)
  assert_eq(second.flushes.val, 1)
}

///|
test "multi_copy_force_flush_during_another_flush_reaches_the_copy" {
  let copy_ref : Ref[@sdk.MultiSpanProcessor?] = Ref(None)
  let first = reentrant_flush_processor(on_flush=() => {
    match copy_ref.val {
      Some(copy) => copy.force_flush()
      None => ()
    }
  })
  let second = reentrant_flush_processor()
  let multi = @sdk.MultiSpanProcessor::new(processors=[first])
  let copy = multi.with_processor(second)
  copy_ref.val = Some(copy)
  multi.force_flush()
  assert_eq(first.flushes.val, 1)
  assert_eq(second.flushes.val, 1)
}

///|
struct CopyShutdownTriggerChild {
  copy : Ref[@sdk.MultiSpanProcessor?]
}

///|
pub impl @sdk.SpanProcessor for CopyShutdownTriggerChild with fn on_start(
  self,
  _span,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CopyShutdownTriggerChild with fn on_end(
  self,
  _data,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CopyShutdownTriggerChild with fn force_flush(
  self,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CopyShutdownTriggerChild with fn shutdown(
  self,
) {
  match self.copy.val {
    Some(copy) => copy.shutdown()
    None => ()
  }
}

///|
pub extend CopyShutdownTriggerChild with @sdk.SpanProcessor::{
  on_start,
  on_end,
  force_flush,
  is_draining,
  shutdown,
}

///|
test "multi_copy_shutdown_during_another_shutdown_reaches_the_copy" {
  let copy_ref : Ref[@sdk.MultiSpanProcessor?] = Ref(None)
  let trigger : CopyShutdownTriggerChild = { copy: copy_ref, }
  let extra : CopyShutdownCountingProcessor = {
    shutdowns: Ref(0),
    flushes: Ref(0),
  }
  let multi = @sdk.MultiSpanProcessor::new(processors=[trigger])
  let copy = multi.with_processor(extra)
  copy_ref.val = Some(copy)
  multi.shutdown()
  assert_true(copy.is_shutdown())
  assert_eq(extra.shutdowns.val, 1)
}

///|
struct CopyShutdownRecordingExporter {
  copy : Ref[@sdk.TracerProviderSdk?]
  names : Ref[Array[String]]
  mut shutdown_called : Bool
}

///|
pub impl @sdk.SpanExporter for CopyShutdownRecordingExporter with fn export_spans(
  self,
  spans,
) {
  if self.shutdown_called {
    return @sdk.ExportFailure("exporter is shut down")
  }
  for data in spans {
    self.names.val.push(data.name)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for CopyShutdownRecordingExporter with fn shutdown(
  self,
) {
  // A copy may still own queued spans that use this exporter. Let its shutdown
  // drain them before this exporter marks itself closed.
  match self.copy.val {
    Some(copy) => copy.shutdown()
    None => ()
  }
  self.shutdown_called = true
}

///|
test "copy_shutdown_drains_its_processor_before_the_outer_exporter_closes" {
  let exporter : CopyShutdownRecordingExporter = {
    copy: Ref(None),
    names: Ref([]),
    shutdown_called: false,
  }
  let base = @sdk.TracerProviderSdk::new(service_name="copy-shutdown-drain")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let batch = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=8,
    max_export_batch_size=8,
    flush_interval_millis=1000000,
  )
  let copy = base.with_span_processor(batch)
  exporter.copy.val = Some(copy)
  copy.get_tracer("copy-shutdown-drain").start_root_span("kept").end()
  assert_eq(exporter.names.val, ["kept"])
  assert_eq(batch.queue_size(), 1)
  base.shutdown()
  assert_eq(exporter.names.val, ["kept", "kept"])
  assert_true(exporter.shutdown_called)
  assert_true(batch.is_shutdown())
}
