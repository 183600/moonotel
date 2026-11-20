///|
struct NestedReentrantExporter {
  provider : Ref[@sdk.TracerProviderSdk?]
  mut reenter : Bool
  mut closed : Bool
}

///|
pub impl @sdk.SpanExporter for NestedReentrantExporter with fn export_spans(
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
pub impl @sdk.SpanExporter for NestedReentrantExporter with fn shutdown(self) {
  self.closed = true
}

///|
pub extend NestedReentrantExporter with @sdk.SpanExporter::{
  export_spans,
  shutdown,
}

///|
test "provider shutdown from a nested batch drain closes the child" {
  let exporter : NestedReentrantExporter = {
    provider: Ref(None),
    reenter: true,
    closed: false,
  }
  let child = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=10,
    max_export_batch_size=10,
    flush_interval_millis=1000000,
  )
  let multi = @sdk.MultiSpanProcessor::new(processors=[child])
  let provider = @sdk.TracerProviderSdk::new(
    service_name="provider-shutdown-nested-batch-drain",
  ).with_span_processor(multi)
  exporter.provider.val = Some(provider)
  child.on_end(probe_span("s0"))
  child.drain_before_shutdown()
  assert_true(provider.is_shutdown())
  assert_true(multi.is_shutdown())
  assert_true(child.is_shutdown())
  assert_true(exporter.closed)
}
