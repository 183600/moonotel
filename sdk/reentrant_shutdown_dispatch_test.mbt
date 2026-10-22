// The SpanProcessor specification says that after `Shutdown` no further
// `OnStart`/`OnEnd` callbacks are allowed. A processor may shut the provider
// down from inside one of those callbacks, so dispatch must re-check the
// provider state before every processor.

///|
struct ReentrantDispatchProcessor {
  name : String
  events : Ref[Array[String]]
  provider : Ref[@sdk.TracerProviderSdk?]
  shutdown_on_start : Bool
  shutdown_on_end : Bool
}

///|
pub impl @sdk.SpanProcessor for ReentrantDispatchProcessor with fn on_start(
  self,
  _span,
) {
  self.events.val.push(self.name + ":start")
  if self.shutdown_on_start {
    match self.provider.val {
      Some(provider) => provider.shutdown()
      None => ()
    }
  }
}

///|
pub impl @sdk.SpanProcessor for ReentrantDispatchProcessor with fn on_end(
  self,
  _data,
) {
  self.events.val.push(self.name + ":end")
  if self.shutdown_on_end {
    match self.provider.val {
      Some(provider) => provider.shutdown()
      None => ()
    }
  }
}

///|
pub impl @sdk.SpanProcessor for ReentrantDispatchProcessor with fn force_flush(
  self,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for ReentrantDispatchProcessor with fn shutdown(
  self,
) {
  self.events.val.push(self.name + ":shutdown")
}

///|
fn dispatch_processor(
  name : String,
  events : Ref[Array[String]],
  provider : Ref[@sdk.TracerProviderSdk?],
  shutdown_on_start? : Bool,
  shutdown_on_end? : Bool,
) -> ReentrantDispatchProcessor {
  {
    name,
    events,
    provider,
    shutdown_on_start: shutdown_on_start.unwrap_or(false),
    shutdown_on_end: shutdown_on_end.unwrap_or(false),
  }
}

///|
test "shutdown_from_on_start_stops_later_on_start_callbacks" {
  let events : Ref[Array[String]] = Ref([])
  let provider_ref : Ref[@sdk.TracerProviderSdk?] = Ref(None)
  let first = dispatch_processor(
    "first",
    events,
    provider_ref,
    shutdown_on_start=true,
  )
  let second = dispatch_processor("second", events, provider_ref)
  let provider = @sdk.TracerProviderSdk::new(service_name="dispatch-start")
    .with_span_processors([first, second])
    .with_sampler(@sdk.Sampler::always_on())
  provider_ref.val = Some(provider)
  let span = provider.get_tracer("dispatch-start").start_root_span("op")
  assert_true(events.val.contains("first:start"))
  assert_true(events.val.contains("first:shutdown"))
  assert_true(events.val.contains("second:shutdown"))
  assert_false(events.val.contains("second:start"))
  span.end()
  assert_false(events.val.contains("first:end"))
  assert_false(events.val.contains("second:end"))
}

///|
test "shutdown_from_on_end_stops_later_on_end_callbacks" {
  let events : Ref[Array[String]] = Ref([])
  let provider_ref : Ref[@sdk.TracerProviderSdk?] = Ref(None)
  let first = dispatch_processor(
    "first",
    events,
    provider_ref,
    shutdown_on_end=true,
  )
  let second = dispatch_processor("second", events, provider_ref)
  let provider = @sdk.TracerProviderSdk::new(service_name="dispatch-end")
    .with_span_processors([first, second])
    .with_sampler(@sdk.Sampler::always_on())
  provider_ref.val = Some(provider)
  let span = provider.get_tracer("dispatch-end").start_root_span("op")
  assert_true(events.val.contains("first:start"))
  assert_true(events.val.contains("second:start"))
  span.end()
  assert_true(events.val.contains("first:end"))
  assert_true(events.val.contains("first:shutdown"))
  assert_true(events.val.contains("second:shutdown"))
  assert_false(events.val.contains("second:end"))
}
