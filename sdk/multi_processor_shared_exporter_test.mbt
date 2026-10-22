// A reentrant shutdown from a child drain must not close an exporter that
// another processor of the same provider still has to drain. The provider
// drains every processor before shutting any exporter down; a child cannot
// be allowed to jump that sequence.

///|
struct SharedDrainExporter {
  exported : Ref[Array[String]]
  mut shutdown_called : Bool
}

///|
pub impl @sdk.SpanExporter for SharedDrainExporter with fn export_spans(
  self,
  spans,
) {
  if self.shutdown_called {
    return @sdk.ExportFailure("exporter is shut down")
  }
  for data in spans {
    self.exported.val.push(data.name)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for SharedDrainExporter with fn shutdown(self) {
  self.shutdown_called = true
}

///|
struct ReentrantDrainChild {
  exporter : &@sdk.SpanExporter
  multi : Ref[@sdk.MultiSpanProcessor?]
  events : Ref[Array[String]]
}

///|
pub impl @sdk.SpanProcessor for ReentrantDrainChild with fn on_start(
  self,
  _span,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for ReentrantDrainChild with fn on_end(
  self,
  _data,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for ReentrantDrainChild with fn force_flush(self) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for ReentrantDrainChild with fn drain_before_shutdown(
  self,
) {
  self.events.val.push("child:drain")
  match self.multi.val {
    Some(multi) => multi.shutdown()
    None => ()
  }
  self.events.val.push("child:drain-end")
}

///|
pub impl @sdk.SpanProcessor for ReentrantDrainChild with fn shutdown(self) {
  self.events.val.push("child:shutdown")
  self.exporter.shutdown()
}

///|
test "child drain cannot close an exporter needed by a later provider drain" {
  let exporter : SharedDrainExporter = {
    exported: Ref([]),
    shutdown_called: false,
  }
  let events : Ref[Array[String]] = Ref([])
  let child : ReentrantDrainChild = {
    exporter,
    multi: Ref(None),
    events,
  }
  let multi = @sdk.MultiSpanProcessor::new(processors=[child])
  child.multi.val = Some(multi)
  let batch = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=100,
    flush_interval_millis=1000000,
  )
  let provider = @sdk.TracerProviderSdk::new(
    service_name="shared-drain-exporter",
  ).with_span_processors([multi, batch]).with_sampler(
    @sdk.Sampler::always_on(),
  )
  provider.get_tracer("shared-drain-exporter").start_root_span("kept").end()
  provider.shutdown()
  assert_eq(exporter.exported.val, ["kept"])
  assert_eq(events.val, [
    "child:drain", "child:drain-end", "child:shutdown",
  ])
}
