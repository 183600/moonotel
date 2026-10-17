// Probe: spans handed to a full BatchSpanProcessor with no timed flush due.
// The processor should not need a second wall-clock read for every span end.

///|
test "zz_batch_on_end_clock" (b : @bench.T) {
  let exporter = NullExporter::{ }
  let processor = BatchSpanProcessor::new(
    exporter,
    max_queue_size=65536,
    max_export_batch_size=65536,
    flush_interval_millis=60000,
  )
  let provider = TracerProviderSdk::new().with_span_processor(processor)
  let tracer = provider.get_tracer("bench")
  b.bench(fn() {
    let span = tracer.start_span("op")
    span.set_attribute("k", StringValue("v"))
    span.end()
  })
}
