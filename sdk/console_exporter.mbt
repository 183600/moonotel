// A `SpanExporter` that prints one summary line per finished span to the
// standard output. Intended for demos, local development and quick smoke
// tests; production deployments should use the OTLP exporters.

///|
pub struct ConsoleSpanExporter {
  mut shutdown_called : Bool
}

// Create a console exporter.
pub fn ConsoleSpanExporter::new() -> ConsoleSpanExporter {
  { shutdown_called: false }
}

// Whether `shutdown` has been called. A shut-down exporter rejects further
// exports.
pub fn ConsoleSpanExporter::is_shutdown(self : ConsoleSpanExporter) -> Bool {
  self.shutdown_called
}

// Render one span as a single summary line:
// `name=<name> trace_id=<hex> span_id=<hex> parent_span_id=<hex> kind=<kind>
//  status=<status> duration_ms=<n> attributes=<n> events=<n> links=<n>`
fn format_span(data : SpanData) -> String {
  let out = StringBuilder()
  out.write_string("span name=")
  out.write_string(data.name)
  out.write_string(" trace_id=")
  out.write_string(data.span_context.trace_id_hex())
  out.write_string(" span_id=")
  out.write_string(data.span_context.span_id_hex())
  if data.parent_span_id.length() > 0 {
    let parent : Array[Int] = []
    for byte in data.parent_span_id {
      parent.push(byte)
    }
    out.write_string(" parent_span_id=")
    out.write_string(@api.bytes_to_hex(parent))
  }
  out.write_string(" kind=")
  out.write_string(data.kind.to_string())
  let duration_millis = (data.end_time_unix_nano - data.start_time_unix_nano) /
    1000000L
  out.write_string(" status=")
  out.write_string(data.status.to_string())
  out.write_string(" duration_ms=")
  out.write_string(duration_millis.to_string())
  out.write_string(" attributes=")
  out.write_string(data.attributes.length().to_string())
  out.write_string(" events=")
  out.write_string(data.events.length().to_string())
  out.write_string(" links=")
  out.write_string(data.links.length().to_string())
  out.to_string()
}

pub impl SpanExporter for ConsoleSpanExporter with export_spans(self, spans) {
  if self.shutdown_called {
    ExportFailure("console exporter is shut down")
  } else {
    for data in spans {
      println(format_span(data))
    }
    ExportSuccess
  }
}

pub impl SpanExporter for ConsoleSpanExporter with shutdown(self) {
  self.shutdown_called = true
}

pub extend ConsoleSpanExporter with SpanExporter::{export_spans, shutdown}
