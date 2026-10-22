// A batch processor sharing an exporter with another processor must not close
// that exporter from inside its own drain. The provider drains every processor
// before shutting any of them down, so a reentrant `shutdown` from the exporter
// has to leave the close to the provider's later shutdown pass.

///|
struct BatchDrainSharedExporter {
  exported : Ref[Array[String]]
  processor : Ref[(&@sdk.SpanProcessor)?]
  mut calls : Int32
  mut shutdown_called : Bool
  mut shutdowns : Int32
}

///|
pub impl @sdk.SpanExporter for BatchDrainSharedExporter with fn export_spans(
  self,
  spans,
) {
  if self.shutdown_called {
    return @sdk.ExportFailure("exporter is shut down")
  }
  for data in spans {
    self.exported.val.push(data.name)
  }
  self.calls = self.calls + 1
  if self.calls == 1 {
    // Simulate an exporter that tears its own processor down while a batch is
    // being drained.
    match self.processor.val {
      Some(processor) => processor.shutdown()
      None => ()
    }
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for BatchDrainSharedExporter with fn shutdown(
  self,
) {
  self.shutdown_called = true
  self.shutdowns = self.shutdowns + 1
}

///|
fn batch_drain_shared_span(name : String) -> @sdk.SpanData {
  {
    name,
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map([], capacity=1),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(Map([], capacity=1)),
    scope_name: "batch-drain-shared-exporter",
    scope_version: "",
  }
}

///|
test "batch drain keeps a shared exporter open for later processors" {
  let exporter : BatchDrainSharedExporter = {
    exported: Ref([]),
    processor: Ref(None),
    calls: 0,
    shutdown_called: false,
    shutdowns: 0,
  }
  let first = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=100,
    flush_interval_millis=1000000,
  )
  exporter.processor.val = Some(first)
  let second = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=100,
    flush_interval_millis=1000000,
  )
  let provider = @sdk.TracerProviderSdk::new(
    service_name="batch-drain-shared-exporter",
  ).with_span_processors([first, second]).with_sampler(
    @sdk.Sampler::always_on(),
  )
  first.on_end(batch_drain_shared_span("first"))
  second.on_end(batch_drain_shared_span("second"))
  provider.shutdown()
  assert_eq(exporter.exported.val, ["first", "second"])
  assert_true(exporter.shutdown_called)
}
