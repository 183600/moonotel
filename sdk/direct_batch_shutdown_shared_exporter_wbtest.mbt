// A direct processor shutdown can race a provider shutdown triggered by the
// exporter. The provider must leave the shared exporter open while the outer
// drain still owns queued spans.

///|
struct DirectShutdownSharedExporter {
  exported : Ref[Array[String]]
  provider : Ref[TracerProviderSdk?]
  mut reenter : Bool
  mut shutdown_called : Bool
  mut shutdowns : Int32
}

///|
pub impl SpanExporter for DirectShutdownSharedExporter with fn export_spans(
  self,
  spans,
) {
  if self.shutdown_called {
    return ExportFailure("exporter is shut down")
  }
  for data in spans {
    self.exported.val.push(data.name)
  }
  if self.reenter {
    self.reenter = false
    match self.provider.val {
      Some(provider) => provider.shutdown()
      None => ()
    }
  }
  ExportSuccess
}

///|
pub impl SpanExporter for DirectShutdownSharedExporter with fn shutdown(
  self,
) {
  self.shutdown_called = true
  self.shutdowns = self.shutdowns + 1
}

///|
pub extend DirectShutdownSharedExporter with SpanExporter::{
  export_spans,
  export_span,
  shutdown,
}

///|
fn direct_shutdown_span(name : String) -> SpanData {
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
    resource: ResourceAttributes::new(Map([], capacity=1)),
    scope_name: "direct-shutdown-shared-exporter",
    scope_version: "",
  }
}

///|
test "direct_batch_shutdown_keeps_a_shared_exporter_open_until_drained" {
  let exporter : DirectShutdownSharedExporter = {
    exported: Ref([]),
    provider: Ref(None),
    reenter: true,
    shutdown_called: false,
    shutdowns: 0,
  }
  let first = BatchSpanProcessor::new(
    exporter,
    max_queue_size=10,
    max_export_batch_size=2,
    flush_interval_millis=1000000,
  )
  let second = BatchSpanProcessor::new(
    exporter,
    max_queue_size=10,
    max_export_batch_size=2,
    flush_interval_millis=1000000,
  )
  let provider = TracerProviderSdk::new(
    service_name="direct-shutdown-shared-exporter",
  ).with_span_processors([first, second]).with_sampler(
    Sampler::always_on(),
  )
  exporter.provider.val = Some(provider)
  for i = 0; i < 5; i = i + 1 {
    first.push_span(direct_shutdown_span("s" + i.to_string()))
  }
  first.shutdown()
  assert_eq(exporter.exported.val, ["s0", "s1", "s2", "s3", "s4"])
  assert_true(exporter.shutdown_called)
}
