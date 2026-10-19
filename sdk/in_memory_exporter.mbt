// An in-memory `SpanExporter` that keeps every exported span.
//
// Useful for tests, demos and local debugging: wire it to a processor and
// inspect (or drain) the spans that would have been sent to a backend. The
// exporter stores batches in order of arrival and never fails while it is
// active.

///|
pub struct InMemorySpanExporter {
  batches : Array[Array[SpanData]]
  mut span_total : Int32
  mut shutdown_called : Bool
}

// Create an empty in-memory exporter.

///|
pub fn InMemorySpanExporter::new() -> InMemorySpanExporter {
  { batches: [], span_total: 0, shutdown_called: false, }
}

// The exported batches, in arrival order. Batches are copied so callers cannot
// mutate the exporter's state.

///|
pub fn InMemorySpanExporter::exported_batches(
  self : InMemorySpanExporter,
) -> Array[Array[SpanData]] {
  let out : Array[Array[SpanData]] = Array(capacity=self.batches.length())
  for batch in self.batches {
    out.push(batch.copy())
  }
  out
}

// Every exported span, flattened in arrival order.

///|
pub fn InMemorySpanExporter::exported_spans(
  self : InMemorySpanExporter,
) -> Array[SpanData] {
  let out : Array[SpanData] = Array(capacity=self.span_total)
  for batch in self.batches {
    for span in batch {
      out.push(span)
    }
  }
  out
}

// Number of spans exported so far.

///|
pub fn InMemorySpanExporter::span_count(self : InMemorySpanExporter) -> Int32 {
  self.span_total
}

// Return every exported span and forget it, leaving the exporter empty.

///|
pub fn InMemorySpanExporter::take_spans(
  self : InMemorySpanExporter,
) -> Array[SpanData] {
  let out = self.exported_spans()
  self.batches.clear()
  self.span_total = 0
  out
}

// Drop every exported span. The shutdown state is unchanged.

///|
pub fn InMemorySpanExporter::clear(self : InMemorySpanExporter) -> Unit {
  self.batches.clear()
  self.span_total = 0
}

// Whether `shutdown` has been called. A shut-down exporter rejects further
// exports.

///|
pub fn InMemorySpanExporter::is_shutdown(self : InMemorySpanExporter) -> Bool {
  self.shutdown_called
}

///|
pub impl SpanExporter for InMemorySpanExporter with fn export_spans(self, spans) {
  if self.shutdown_called {
    ExportFailure("in-memory exporter is shut down")
  } else if spans.length() == 0 {
    ExportSuccess
  } else {
    self.batches.push(spans.copy())
    self.span_total = self.span_total + spans.length()
    ExportSuccess
  }
}

///|
pub impl SpanExporter for InMemorySpanExporter with fn export_span(self, data) {
  if self.shutdown_called {
    ExportFailure("in-memory exporter is shut down")
  } else {
    // `[data]` is freshly allocated, so no defensive copy is needed.
    self.batches.push([data])
    self.span_total = self.span_total + 1
    ExportSuccess
  }
}

///|
pub impl SpanExporter for InMemorySpanExporter with fn shutdown(self) {
  self.shutdown_called = true
}

///|
pub extend InMemorySpanExporter with SpanExporter::{export_spans, export_span, shutdown}
