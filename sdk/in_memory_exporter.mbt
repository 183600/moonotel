// An in-memory `SpanExporter` that keeps every exported span.
//
// Useful for tests, demos and local debugging: wire it to a processor and
// inspect (or drain) the spans that would have been sent to a backend. The
// exporter stores batches in order of arrival and never fails while it is
// active.

///|
pub struct InMemorySpanExporter {
  batches : Array[Array[SpanData]]
  mut shutdown_called : Bool
}

// Create an empty in-memory exporter.
pub fn InMemorySpanExporter::new() -> InMemorySpanExporter {
  { batches: [], shutdown_called: false }
}

// The exported batches, in arrival order. Batches are copied so callers cannot
// mutate the exporter's state.
pub fn InMemorySpanExporter::exported_batches(
  self : InMemorySpanExporter
) -> Array[Array[SpanData]] {
  let out : Array[Array[SpanData]] = []
  for batch in self.batches {
    out.push(batch.copy())
  }
  out
}

// Every exported span, flattened in arrival order.
pub fn InMemorySpanExporter::exported_spans(
  self : InMemorySpanExporter
) -> Array[SpanData] {
  let out : Array[SpanData] = []
  for batch in self.batches {
    for span in batch {
      out.push(span)
    }
  }
  out
}

// Number of spans exported so far.
pub fn InMemorySpanExporter::span_count(self : InMemorySpanExporter) -> Int {
  let mut total = 0
  for batch in self.batches {
    total = total + batch.length()
  }
  total
}

// Return every exported span and forget it, leaving the exporter empty.
pub fn InMemorySpanExporter::take_spans(
  self : InMemorySpanExporter
) -> Array[SpanData] {
  let out = self.exported_spans()
  self.batches.clear()
  out
}

// Drop every exported span. The shutdown state is unchanged.
pub fn InMemorySpanExporter::clear(self : InMemorySpanExporter) -> Unit {
  self.batches.clear()
}

// Whether `shutdown` has been called. A shut-down exporter rejects further
// exports.
pub fn InMemorySpanExporter::is_shutdown(self : InMemorySpanExporter) -> Bool {
  self.shutdown_called
}

pub impl SpanExporter for InMemorySpanExporter with export_spans(self, spans) {
  if self.shutdown_called {
    ExportFailure("in-memory exporter is shut down")
  } else if spans.length() == 0 {
    ExportSuccess
  } else {
    self.batches.push(spans.copy())
    ExportSuccess
  }
}

pub impl SpanExporter for InMemorySpanExporter with shutdown(self) {
  self.shutdown_called = true
}

pub extend InMemorySpanExporter with SpanExporter::{export_spans, shutdown}
