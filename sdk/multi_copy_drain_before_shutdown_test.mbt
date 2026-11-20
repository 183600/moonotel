// The provider promises to drain every processor it is about to shut down
// before any exporter is closed. A `MultiSpanProcessor` copy that shares the
// shutdown marker with an already shut-down source can still own a child added
// after that shutdown; the provider must drain that child during its drain
// pass, not while sibling processors are already being closed.

///|
struct CopyDrainProbe {
  name : String
  log : Ref[Array[String]]
}

///|
pub impl @sdk.SpanProcessor for CopyDrainProbe with fn on_start(self, _span) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CopyDrainProbe with fn on_end(self, _data) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CopyDrainProbe with fn force_flush(self) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for CopyDrainProbe with fn drain_before_shutdown(
  self,
) {
  self.log.val.push(self.name + ":drain")
}

///|
pub impl @sdk.SpanProcessor for CopyDrainProbe with fn shutdown(self) {
  self.log.val.push(self.name + ":shutdown")
}

///|
fn copy_drain_probe(name : String, log : Ref[Array[String]]) -> CopyDrainProbe {
  { name, log, }
}

///|
test "provider drains a child added to an already-shut-down multi copy before shutting siblings" {
  let log : Ref[Array[String]] = Ref([])
  let source = @sdk.MultiSpanProcessor::new(processors=[
    copy_drain_probe("source", log),
  ])
  source.shutdown()
  assert_eq(log.val, ["source:drain", "source:shutdown"])
  let copy = source.with_processor(copy_drain_probe("added", log))
  let provider = @sdk.TracerProviderSdk::new(
    service_name="multi-copy-pre-drain",
  ).with_span_processors([copy_drain_probe("sibling", log), copy])
  provider.shutdown()
  assert_eq(log.val, [
    "source:drain", "source:shutdown", "sibling:drain", "added:drain", "sibling:shutdown",
    "added:shutdown",
  ])
}
