// Span processors and exporters.
//
// A SpanProcessor is notified when spans start and end. The SimpleSpanProcessor
// exports each span immediately; the BatchSpanProcessor buffers spans and
// exports them in batches.

// Result of an export attempt.
pub(all) enum ExportResult {
  ExportSuccess
  ExportFailure(String)
} derive(Eq, @debug.Debug)

// Whether an export result represents success.
pub fn ExportResult::is_success(self : ExportResult) -> Bool {
  match self {
    ExportSuccess => true
    ExportFailure(_) => false
  }
}

// Sink that receives finished spans.
pub(open) trait SpanExporter {
  export_spans(Self, Array[SpanData]) -> ExportResult
  shutdown(Self) -> Unit
}

// Hook invoked as spans start and end.
pub(open) trait SpanProcessor {
  on_start(Self, SpanSdk) -> Unit
  on_end(Self, SpanData) -> Unit
  force_flush(Self) -> Unit
  shutdown(Self) -> Unit
}
