// Span processors and exporters.
//
// A SpanProcessor is notified when spans start and end. The SimpleSpanProcessor
// exports each span immediately; the BatchSpanProcessor buffers spans and
// exports them in batches.

// Result of an export attempt.

///|
pub(all) enum ExportResult {
  ExportSuccess
  ExportFailure(String)
} derive(Eq, @debug.Debug)

// Whether an export result represents success.

///|
pub fn ExportResult::is_success(self : ExportResult) -> Bool {
  match self {
    ExportSuccess => true
    ExportFailure(_) => false
  }
}

// Sink that receives finished spans.

///|
pub(open) trait SpanExporter {
  fn export_spans(Self, Array[SpanData]) -> ExportResult
  // Export a single span. The default wraps it in a one-element batch.
  fn export_span(Self, SpanData) -> ExportResult = _
  fn shutdown(Self) -> Unit
}

///|
impl SpanExporter with export_span(self, data) {
  self.export_spans([data])
}

// Hook invoked as spans start and end.

///|
pub(open) trait SpanProcessor {
  fn on_start(Self, SpanSdk) -> Unit
  fn on_end(Self, SpanData) -> Unit
  fn force_flush(Self) -> Unit
  // Drain buffered spans without shutting the exporter down. The provider
  // calls this for every processor before shutting any of them down, so
  // processors that share an exporter cannot lose queued spans because an
  // earlier shutdown closed that exporter. The default is a no-op.
  fn drain_before_shutdown(Self) -> Unit = _
  fn shutdown(Self) -> Unit
}

///|
impl SpanProcessor with drain_before_shutdown(self) {
  let _ = self
}

///|
pub extend ExportResult with Eq::{not_equal, equal}

///|
pub extend ExportResult with @debug.Debug::{to_repr}
