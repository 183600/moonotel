// A SpanProcessor that exports every finished sampled span immediately.
// Suitable for tests, demos and low-throughput services.

///|
pub struct SimpleSpanProcessor {
  exporter : &SpanExporter
  mut shutdown_called : Bool
  mut export_failures : UInt64
}

// Create a processor that forwards each finished span to `exporter`.

///|
pub fn SimpleSpanProcessor::new(
  exporter : &SpanExporter,
) -> SimpleSpanProcessor {
  { exporter, shutdown_called: false, export_failures: 0, }
}

// Whether `shutdown` has been called.

///|
pub fn SimpleSpanProcessor::is_shutdown(self : SimpleSpanProcessor) -> Bool {
  self.shutdown_called
}

// Number of export attempts that failed.

///|
pub fn SimpleSpanProcessor::export_failures(
  self : SimpleSpanProcessor,
) -> UInt64 {
  self.export_failures
}

///|
pub impl SpanProcessor for SimpleSpanProcessor with fn on_start(self, _span) {
  let _ = self
}

///|
pub impl SpanProcessor for SimpleSpanProcessor with fn on_end(self, data) {
  if !self.shutdown_called && data.span_context.is_sampled() {
    match self.exporter.export_span(data) {
      ExportSuccess => ()
      ExportFailure(_) => self.export_failures = self.export_failures + 1
    }
  }
}

///|
pub impl SpanProcessor for SimpleSpanProcessor with fn force_flush(self) {
  let _ = self
}

///|
pub impl SpanProcessor for SimpleSpanProcessor with fn shutdown(self) {
  if !self.shutdown_called {
    self.shutdown_called = true
    self.exporter.shutdown()
  }
}

///|
pub extend SimpleSpanProcessor with SpanProcessor::{
  on_end,
  on_start,
  force_flush,
  drain_before_shutdown,
  shutdown,
}
