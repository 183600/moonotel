// A batch processor must stay idempotent when the exporter calls back into
// `shutdown` while the queued spans are being drained.

///|
struct ReentrantShutdownExporter {
  processor : Ref[(&@sdk.SpanProcessor)?]
  batches : Ref[Int32]
  shutdowns : Ref[Int32]
}

///|
pub impl @sdk.SpanExporter for ReentrantShutdownExporter with fn export_spans(
  self,
  spans,
) {
  let _ = spans
  self.batches.val = self.batches.val + 1
  match self.processor.val {
    Some(processor) => processor.shutdown()
    None => ()
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for ReentrantShutdownExporter with fn shutdown(
  self,
) {
  self.shutdowns.val = self.shutdowns.val + 1
}

///|
test "batch_shutdown_is_idempotent_when_the_exporter_reenters" {
  let exporter : ReentrantShutdownExporter = {
    processor: Ref(None),
    batches: Ref(0),
    shutdowns: Ref(0),
  }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=4,
    max_export_batch_size=4,
  )
  exporter.processor.val = Some(processor)
  processor.on_end(probe_span("s0"))
  processor.on_end(probe_span("s1"))
  assert_eq(processor.queue_size(), 2)
  processor.shutdown()
  assert_true(processor.is_shutdown())
  // The queued spans are exported exactly once and the reentrant call does not
  // shut the exporter down a second time.
  assert_eq(exporter.batches.val, 1)
  assert_eq(exporter.shutdowns.val, 1)
  processor.shutdown()
  assert_eq(exporter.shutdowns.val, 1)
}
