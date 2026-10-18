// A SpanProcessor that exports every finished sampled span immediately.
// Suitable for tests, demos and low-throughput services.

///|
pub struct SimpleSpanProcessor {
  exporter : &SpanExporter
  mut shutdown_called : Bool
}

// Create a processor that forwards each finished span to `exporter`.

///|
pub fn SimpleSpanProcessor::new(
  exporter : &SpanExporter,
) -> SimpleSpanProcessor {
  { exporter, shutdown_called: false, }
}

// Whether `shutdown` has been called.

///|
pub fn SimpleSpanProcessor::is_shutdown(self : SimpleSpanProcessor) -> Bool {
  self.shutdown_called
}

///|
pub impl SpanProcessor for SimpleSpanProcessor with fn on_start(self, _span) {
  let _ = self
}

///|
pub impl SpanProcessor for SimpleSpanProcessor with fn on_end(self, data) {
  if !self.shutdown_called && data.span_context.is_sampled() {
    let _ = self.exporter.export_spans([data])
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
  shutdown,
}
