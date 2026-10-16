// A small demo client that calls the demo server with tracing enabled and
// prints the finished spans. Start the server first:
//
//   moon run examples/demo_server --target native
//   moon run examples/demo_client --target native
//
// The client injects the W3C `traceparent`/`tracestate` and `baggage` headers,
// so the server span joins the same trace. In a real deployment, replace
// `StdoutExporter` with `@otlp.OtlpHttpExporter` to ship spans to a collector.

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
  let provider = @sdk.TracerProviderSdk::new(service_name="demo-client")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(StdoutExporter::{}))
  let tracer = provider.get_tracer("demo-client")
  let previous = @context.attach(
    @context.Context::root().with_value("user.id", "demo-user"),
  )
  defer @context.detach(previous)
  let outcome = try {
    let (response, body) = @client.get(
      "http://127.0.0.1:8080/hello",
      tracer=tracer,
    )
    println("GET /hello -> \{response.code}: \{body.text()}")
  } catch {
    error =>
      println("request failed (is the demo server running?): \{error.to_string()}")
  }
  let _ = outcome
  provider.force_flush()
  provider.shutdown()
}
