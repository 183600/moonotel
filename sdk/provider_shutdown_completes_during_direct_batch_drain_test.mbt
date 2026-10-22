// A provider shutdown triggered from a batch exporter while the batch
// processor is being shut down directly must not leave the other processors
// open forever. The provider finishes its shutdown once that outer drain ends.

///|
struct ReentrantProviderExporter {
  provider : Ref[@sdk.TracerProviderSdk?]
  mut reenter : Bool
}

///|
pub impl @sdk.SpanExporter for ReentrantProviderExporter with fn export_spans(
  self,
  _spans,
) {
  if self.reenter {
    self.reenter = false
    match self.provider.val {
      Some(provider) => provider.shutdown()
      None => ()
    }
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for ReentrantProviderExporter with fn shutdown(
  self,
) {
  let _ = self
}

///|
pub extend ReentrantProviderExporter with @sdk.SpanExporter::{export_spans, shutdown}

///|
test "provider_shutdown_from_a_direct_batch_drain_closes_other_processors" {
  let exporter : ReentrantProviderExporter = {
    provider: Ref(None),
    reenter: true,
  }
  let first = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=10,
    max_export_batch_size=10,
    flush_interval_millis=1000000,
  )
  let second = @sdk.BatchSpanProcessor::new(
    ProbeExporter::{ names: [] },
    max_queue_size=10,
    max_export_batch_size=10,
    flush_interval_millis=1000000,
  )
  let provider = @sdk.TracerProviderSdk::new(
    service_name="provider-shutdown-direct-batch",
  ).with_span_processors([first, second]).with_sampler(@sdk.Sampler::always_on())
  exporter.provider.val = Some(provider)
  first.on_end(probe_span("s0"))
  first.on_end(probe_span("s1"))
  // The exporter calls provider.shutdown while this direct drain is running.
  first.shutdown()
  assert_true(provider.is_shutdown())
  assert_true(first.is_shutdown())
  assert_true(second.is_shutdown())
}
