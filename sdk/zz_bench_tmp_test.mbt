///|
struct NullExporter {}

///|
pub impl SpanExporter for NullExporter with export_spans(self, _spans) {
  let _ = self
  ExportSuccess
}

///|
pub impl SpanExporter for NullExporter with shutdown(self) {
  let _ = self
}

///|
pub extend NullExporter with SpanExporter::{export_spans, shutdown}

///|
test "zz_bench_sdk" (b : @bench.T) {
  let exporter = NullExporter::{ }
  let provider = TracerProviderSdk::new()
    .with_span_processor(SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("bench")
  let bare_provider = TracerProviderSdk::new()
  let bare_tracer = bare_provider.get_tracer("bench")
  b.bench(fn() {
    let span = bare_tracer.start_span("op")
    let _ = span
  })
  b.bench(fn() {
    let span = bare_tracer.start_span("op")
    span.end()
  })
  b.bench(fn() {
    let span = tracer.start_span("op")
    span.end()
  })
  b.bench(fn() {
    let span = tracer.start_span("op")
    span.set_attribute("key", StringValue("value"))
    span.set_attribute("num", IntValue(42L))
    span.add_event("evt")
    span.end()
  })
  let attributes : Map[String, AttributeValue] = Map([
    ("http.request.method", StringValue("GET")),
    ("url.full", StringValue("http://example.com/path")),
    ("server.address", StringValue("example.com")),
    ("server.port", IntValue(80L)),
  ])
  b.bench(fn() {
    let span = tracer.start_span("op", attributes~)
    span.end()
  })
  b.bench(fn() {
    let sc = @api.span_context(
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      [1, 2, 3, 4, 5, 6, 7, 8],
      1,
    )
    let sampler = Sampler::trace_id_ratio_based(0.5)
    let _ = sampler.should_sample(Some(sc), sc.trace_id_view())
  })
  b.bench(fn() {
    let gen = IdGenerator::deterministic(42UL)
    let _ = gen.generate_trace_id()
    let _ = gen.generate_span_id()
  })
}
