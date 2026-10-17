///|
struct ProbeExporter {}

///|
pub impl SpanExporter for ProbeExporter with export_spans(self, _spans) {
  let _ = self
  ExportSuccess
}

///|
pub impl SpanExporter for ProbeExporter with shutdown(self) {
  let _ = self
}

///|
pub extend ProbeExporter with SpanExporter::{export_spans, shutdown}

///|
test "zz_myprobe_sdk_wb" (b : @bench.T) {
  let provider = TracerProviderSdk::new()
  let limits = provider.span_limits()
  let resource = provider.resource()
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = @api.span_context(trace_id, span_id, 1)
  let processors : Array[&SpanProcessor] = []
  b.bench(fn() {
    let _ = @api.span_context(trace_id, span_id, 1)
  })
  b.bench(fn() {
    let _ = create_span(
      "op", sc, [], @api.SpanKind::Internal, 0L, true, None, limits,
      processors, resource, "bench", "",
    )
  })
  let span = create_span(
    "op", sc, [], @api.SpanKind::Internal, 0L, true, None, limits,
    processors, resource, "bench", "",
  )
  b.bench(fn() {
    let _ = SpanData::from_span(span)
  })
  b.bench(fn() {
    let _ = unix_nano_now()
  })
  b.bench(fn() {
    let gen = IdGenerator::random()
    let _ = gen.generate_trace_id()
    let _ = gen.generate_span_id()
  })
  b.bench(fn() {
    let gen = IdGenerator::deterministic(42UL)
    let _ = gen.generate_trace_id()
    let _ = gen.generate_span_id()
  })
  let tracer = provider.get_tracer("bench")
  b.bench(fn() {
    let s = tracer.start_span("op", start_time_unix_nano=0L)
    let _ = s
  })
  b.bench(fn() {
    let s = tracer.start_span("op", start_time_unix_nano=0L)
    s.end(end_time_unix_nano=0L)
  })
}
