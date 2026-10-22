// A `MultiSpanProcessor` drains each child exactly once. `TracerProviderSdk`
// already calls `drain_before_shutdown` before it calls `shutdown`, and a
// child's drain may itself trigger a reentrant shutdown; neither may cause a
// child to be drained again after it has already been shut down.

///|
struct DrainProbeProcessor {
  name : String
  log : Ref[Array[String]]
  multi : Ref[@sdk.MultiSpanProcessor?]
  reenter : Bool
}

///|
pub impl @sdk.SpanProcessor for DrainProbeProcessor with fn on_start(
  self,
  _span,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for DrainProbeProcessor with fn on_end(
  self,
  _data,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for DrainProbeProcessor with fn force_flush(
  self,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for DrainProbeProcessor with fn drain_before_shutdown(
  self,
) {
  self.log.val.push(self.name + ":drain")
  if self.reenter {
    match self.multi.val {
      Some(multi) => multi.shutdown()
      None => ()
    }
  }
}

///|
pub impl @sdk.SpanProcessor for DrainProbeProcessor with fn shutdown(self) {
  self.log.val.push(self.name + ":shutdown")
}

///|
fn drain_probe(
  name : String,
  log : Ref[Array[String]],
  reenter? : Bool,
) -> DrainProbeProcessor {
  {
    name,
    log,
    multi: Ref(None),
    reenter: reenter.unwrap_or(false),
  }
}

///|
test "provider shutdown drains multi children once before shutting them down" {
  let log : Ref[Array[String]] = Ref([])
  let multi = @sdk.MultiSpanProcessor::new(processors=[
    drain_probe("a", log),
    drain_probe("b", log),
  ])
  let provider = @sdk.TracerProviderSdk::new(
    service_name="multi-drain-once",
  ).with_span_processor(multi)
  provider.shutdown()
  assert_eq(log.val, [
    "a:drain", "b:drain", "a:shutdown", "b:shutdown",
  ])
}

///|
test "reentrant shutdown during a child drain keeps remaining children ordered" {
  let log : Ref[Array[String]] = Ref([])
  let first = drain_probe("a", log, reenter=true)
  let second = drain_probe("b", log)
  let multi = @sdk.MultiSpanProcessor::new(processors=[first, second])
  first.multi.val = Some(multi)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="multi-drain-reentrant",
  ).with_span_processor(multi)
  provider.shutdown()
  assert_eq(log.val, [
    "a:drain", "b:drain", "a:shutdown", "b:shutdown",
  ])
}

///|
test "copy shutdown does not drain a child that a shared copy already drained" {
  let log : Ref[Array[String]] = Ref([])
  let multi = @sdk.MultiSpanProcessor::new(processors=[drain_probe("a", log)])
  let copy = multi.with_processor(drain_probe("b", log))
  multi.drain_before_shutdown()
  assert_eq(log.val, ["a:drain"])
  copy.shutdown()
  assert_eq(log.val, [
    "a:drain", "b:drain", "a:shutdown", "b:shutdown",
  ])
}

///|
struct EventProbeProcessor {
  name : String
  log : Ref[Array[String]]
  multi : Ref[@sdk.MultiSpanProcessor?]
  shutdown_on_event : Bool
}

///|
pub impl @sdk.SpanProcessor for EventProbeProcessor with fn on_start(
  self,
  span,
) {
  self.log.val.push(self.name + ":start:" + span.name())
  if self.shutdown_on_event {
    match self.multi.val {
      Some(multi) => multi.shutdown()
      None => ()
    }
  }
}

///|
pub impl @sdk.SpanProcessor for EventProbeProcessor with fn on_end(
  self,
  data,
) {
  self.log.val.push(self.name + ":end:" + data.name)
  if self.shutdown_on_event {
    match self.multi.val {
      Some(multi) => multi.shutdown()
      None => ()
    }
  }
}

///|
pub impl @sdk.SpanProcessor for EventProbeProcessor with fn force_flush(
  self,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for EventProbeProcessor with fn shutdown(self) {
  self.log.val.push(self.name + ":shutdown")
}

///|
fn event_probe(
  name : String,
  log : Ref[Array[String]],
  shutdown_on_event? : Bool,
) -> EventProbeProcessor {
  {
    name,
    log,
    multi: Ref(None),
    shutdown_on_event: shutdown_on_event.unwrap_or(false),
  }
}

///|
test "span events stop at a child that shuts the multi processor down" {
  let log : Ref[Array[String]] = Ref([])
  let first = event_probe("a", log, shutdown_on_event=true)
  let second = event_probe("b", log)
  let multi = @sdk.MultiSpanProcessor::new(processors=[first, second])
  first.multi.val = Some(multi)
  let provider = @sdk.TracerProviderSdk::new(
    service_name="multi-event-reentrant",
  ).with_span_processor(multi)
  let span = provider.get_tracer("multi-event-reentrant").start_root_span("op")
  span.end()
  // `a` shuts the processor down while handling `on_start`, so `b` must not
  // see the start or the end event, and `a` itself is no longer active when
  // the span ends.
  assert_eq(log.val, [
    "a:start:op", "a:shutdown", "b:shutdown",
  ])
}
