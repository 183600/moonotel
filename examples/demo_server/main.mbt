// A small demo server that traces every request and prints the finished
// spans. Run with `moon run examples/demo_server --target native`, then call
// it from the instrumented client (or `curl`) and watch the spans appear.
//
// In a real deployment, replace `StdoutExporter` with
// `@otlp.OtlpHttpExporter` / `@otlp_async` to ship spans to a collector.

struct StdoutExporter {
}

pub impl @sdk.SpanExporter for StdoutExporter with export_spans(self, spans) {
  let _ = self
  for span in spans {
    println(
      "span name=\{span.name} trace_id=\{span.span_context.trace_id_hex()} span_id=\{span.span_context.span_id_hex()} status=\{span.status.to_string()}",
    )
  }
  @sdk.ExportSuccess
}

pub impl @sdk.SpanExporter for StdoutExporter with shutdown(self) {
  let _ = self
}

async fn main {
  let provider = @sdk.TracerProviderSdk::new(service_name="demo-server")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(StdoutExporter::{}))
  let addr = @socket.Addr::parse("127.0.0.1:8080")
  println("listening on http://127.0.0.1:8080")
  @server.run_server(
    addr,
    call => {
      match call.path() {
        "/hello" => {
          match call.start_span("build-greeting") {
            Some(span) => {
              span.add_event("greeting.built")
              span.end()
            }
            None => ()
          }
          call.respond(200, body="hello from " + call.method())
        }
        _ => call.respond(404, body="not found")
      }
    },
    tracer=provider.get_tracer("demo-server"),
  )
}
