// A `SpanExporter` that prints one summary line per finished span to the
// standard output. Intended for demos, local development and quick smoke
// tests; production deployments should use the OTLP exporters.

///|
pub struct ConsoleSpanExporter {
  mut shutdown_called : Bool
}

// Create a console exporter.

///|
pub fn ConsoleSpanExporter::new() -> ConsoleSpanExporter {
  { shutdown_called: false, }
}

// Whether `shutdown` has been called. A shut-down exporter rejects further
// exports.

///|
pub fn ConsoleSpanExporter::is_shutdown(self : ConsoleSpanExporter) -> Bool {
  self.shutdown_called
}

// Lower-case hex character of a nibble value.

///|
fn hex_nibble_char(value : Int32) -> Char {
  if value < 10 {
    (value + 48).unsafe_to_char()
  } else {
    (value + 87).unsafe_to_char()
  }
}

// Append the hex form of an `Int32` byte array, matching `@api.bytes_to_hex`
// (which takes `Array[Int]`).

///|
fn write_int32_hex(out : StringBuilder, bytes : Array[Int32]) -> Unit {
  for byte in bytes {
    if byte >= 0 && byte < 256 {
      out.write_char(hex_nibble_char(byte >> 4))
    } else {
      out.write_char('0')
    }
    out.write_char(hex_nibble_char(byte & 0x0F))
  }
}

// Render an array value as `[a, b, c]` from already-rendered element strings.

///|
fn format_array(items : Array[String]) -> String {
  "[" + items.join(", ") + "]"
}

// Append text with control characters and backslashes escaped, so a span name,
// event name, attribute value or status description can never introduce an
// extra line into the console summary (or hide its start with a carriage
// return).

///|
fn write_escaped_console_text(out : StringBuilder, text : String) -> Unit {
  let len = text.length()
  let mut i = 0
  while i < len {
    let code = text.unsafe_get(i).to_int()
    if code == 0x5C {
      out.write_string("\\\\")
    } else if code == 0x0A {
      out.write_string("\\n")
    } else if code == 0x0D {
      out.write_string("\\r")
    } else if code == 0x09 {
      out.write_string("\\t")
    } else if code < 0x20 ||
      code == 0x7F ||
      (code >= 0x80 && code <= 0x9F) ||
      code == 0x2028 ||
      code == 0x2029 {
      out.write_string("\\u")
      out.write_char(hex_nibble_char((code >> 12) & 0x0F))
      out.write_char(hex_nibble_char((code >> 8) & 0x0F))
      out.write_char(hex_nibble_char((code >> 4) & 0x0F))
      out.write_char(hex_nibble_char(code & 0x0F))
    } else {
      out.write_char(code.unsafe_to_char())
    }
    i = i + 1
  }
}

///|
fn escape_console_text(text : String) -> String {
  let out = StringBuilder(size_hint=text.length())
  write_escaped_console_text(out, text)
  out.to_string()
}

// Render a single attribute value compactly, so the console output stays on
// one line regardless of the value's shape.

///|
fn format_attribute_value(value : AttributeValue) -> String {
  match value {
    StringValue(text) => escape_console_text(text)
    BoolValue(flag) => flag.to_string()
    IntValue(number) => number.to_string()
    DoubleValue(number) => number.to_string()
    StringArrayValue(items) =>
      format_array(items.map(fn(item) { escape_console_text(item) }))
    BoolArrayValue(items) => format_array(items.map(fn(item) { item.to_string() }))
    IntArrayValue(items) => format_array(items.map(fn(item) { item.to_string() }))
    DoubleArrayValue(items) => format_array(items.map(fn(item) { item.to_string() }))
  }
}

// Render one span as a single summary line:
// `name=<name> trace_id=<hex> span_id=<hex> parent_span_id=<hex> kind=<kind>
//  status=<status> duration_ms=<n> attributes=<n>{key=value,...} events=<n>
//  links=<n>`. Attribute values and event names are appended after the counts
// so the line stays useful for demos without breaking the summary prefix.
// User-provided text is escaped so it cannot introduce another line.

///|
fn format_span(data : SpanData) -> String {
  let out = StringBuilder()
  out.write_string("span name=")
  write_escaped_console_text(out, data.name)
  out.write_string(" trace_id=")
  out.write_string(data.span_context.trace_id_hex())
  out.write_string(" span_id=")
  out.write_string(data.span_context.span_id_hex())
  if data.parent_span_id.length() > 0 {
    out.write_string(" parent_span_id=")
    write_int32_hex(out, data.parent_span_id)
  }
  out.write_string(" kind=")
  out.write_string(data.kind.to_string())
  let duration_millis = (data.end_time_unix_nano - data.start_time_unix_nano) /
    1000000L
  out.write_string(" status=")
  out.write_string(data.status.to_string())
  if data.status_description.length() > 0 {
    out.write_string(" status_description=")
    write_escaped_console_text(out, data.status_description)
  }
  out.write_string(" duration_ms=")
  out.write_string(duration_millis.to_string())
  out.write_string(" attributes=")
  out.write_string(data.attributes.length().to_string())
  if data.attributes.length() > 0 {
    out.write_char('{')
    let mut first = true
    for key, value in data.attributes {
      if !first {
        out.write_string(", ")
      }
      first = false
      write_escaped_console_text(out, key)
      out.write_char('=')
      out.write_string(format_attribute_value(value))
    }
    out.write_char('}')
  }
  out.write_string(" events=")
  out.write_string(data.events.length().to_string())
  if data.events.length() > 0 {
    out.write_char('[')
    for i = 0; i < data.events.length(); i = i + 1 {
      if i > 0 {
        out.write_string(", ")
      }
      write_escaped_console_text(out, data.events[i].name)
    }
    out.write_char(']')
  }
  out.write_string(" links=")
  out.write_string(data.links.length().to_string())
  out.to_string()
}

///|
pub impl SpanExporter for ConsoleSpanExporter with fn export_spans(self, spans) {
  if self.shutdown_called {
    ExportFailure("console exporter is shut down")
  } else {
    for data in spans {
      println(format_span(data))
    }
    ExportSuccess
  }
}

///|
pub impl SpanExporter for ConsoleSpanExporter with fn export_span(self, data) {
  if self.shutdown_called {
    ExportFailure("console exporter is shut down")
  } else {
    println(format_span(data))
    ExportSuccess
  }
}

///|
pub impl SpanExporter for ConsoleSpanExporter with fn shutdown(self) {
  self.shutdown_called = true
}

///|
pub extend ConsoleSpanExporter with SpanExporter::{export_spans, export_span, shutdown}
