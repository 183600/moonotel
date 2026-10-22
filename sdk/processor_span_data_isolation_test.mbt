// A `SpanData` snapshot is immutable by contract. Each processor receives its
// own copy, so a processor that mutates the snapshot cannot affect a later
// processor or the ended span's accessors.

///|
struct IsolationMutatingProcessor {}

///|
fn IsolationMutatingProcessor::new() -> IsolationMutatingProcessor {
  IsolationMutatingProcessor::{ }
}

///|
pub impl @sdk.SpanProcessor for IsolationMutatingProcessor with fn on_start(
  self,
  _span,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for IsolationMutatingProcessor with fn on_end(
  self,
  data,
) {
  let _ = self
  data.attributes.set("injected", @sdk.StringValue("span"))
  if data.events.length() > 0 {
    data.events[0].attributes.set("injected", @sdk.StringValue("event"))
  }
  if data.links.length() > 0 {
    data.links[0].attributes.set("injected", @sdk.StringValue("link"))
  }
  data.resource.set("injected", @sdk.StringValue("resource"))
  if data.span_context.is_valid() {
    data.span_context.trace_id_view()[0] = 0xEE
    data.span_context.span_id_view()[0] = 0xEE
  }
  if data.parent_span_id.length() > 0 {
    data.parent_span_id[0] = 0xEE
  }
}

///|
pub impl @sdk.SpanProcessor for IsolationMutatingProcessor with fn force_flush(
  self,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for IsolationMutatingProcessor with fn shutdown(
  self,
) {
  let _ = self
}

///|
pub extend IsolationMutatingProcessor with @sdk.SpanProcessor::{
  on_start,
  on_end,
  force_flush,
  shutdown,
}

///|
struct IsolationObserverProcessor {
  expected_trace_id : String
  expected_span_id : Ref[String]
  expected_parent_id : String
  failures : Array[String]
}

///|
fn IsolationObserverProcessor::new(
  expected_trace_id : String,
  expected_span_id : String,
  expected_parent_id : String,
) -> IsolationObserverProcessor {
  {
    expected_trace_id,
    expected_span_id: Ref(expected_span_id),
    expected_parent_id,
    failures: [],
  }
}

///|
pub impl @sdk.SpanProcessor for IsolationObserverProcessor with fn on_start(
  self,
  _span,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for IsolationObserverProcessor with fn on_end(
  self,
  data,
) {
  if data.attributes.get("injected") is Some(_) {
    self.failures.push("span attribute leaked from an earlier processor")
  }
  if data.attributes.get("kept") != Some(@sdk.IntValue(7L)) {
    self.failures.push("original span attribute missing")
  }
  if data.events.length() != 1 {
    self.failures.push("event count changed")
  } else {
    if data.events[0].attributes.get("injected") is Some(_) {
      self.failures.push("event attribute leaked from an earlier processor")
    }
    if data.events[0].attributes.get("event") !=
      Some(@sdk.StringValue("kept")) {
      self.failures.push("original event attribute missing")
    }
  }
  if data.links.length() != 1 {
    self.failures.push("link count changed")
  } else {
    if data.links[0].attributes.get("injected") is Some(_) {
      self.failures.push("link attribute leaked from an earlier processor")
    }
    if data.links[0].attributes.get("link") !=
      Some(@sdk.StringValue("kept")) {
      self.failures.push("original link attribute missing")
    }
  }
  if data.resource.get("injected") is Some(_) {
    self.failures.push("resource attribute leaked from an earlier processor")
  }
  if data.span_context.trace_id_hex() != self.expected_trace_id {
    self.failures.push("trace ID changed")
  }
  if data.span_context.span_id_hex() != self.expected_span_id.val {
    self.failures.push("span ID changed")
  }
  if @api.bytes_to_hex(data.parent_span_id) != self.expected_parent_id {
    self.failures.push("parent span ID changed")
  }
}

///|
pub impl @sdk.SpanProcessor for IsolationObserverProcessor with fn force_flush(
  self,
) {
  let _ = self
}

///|
pub impl @sdk.SpanProcessor for IsolationObserverProcessor with fn shutdown(
  self,
) {
  let _ = self
}

///|
pub extend IsolationObserverProcessor with @sdk.SpanProcessor::{
  on_start,
  on_end,
  force_flush,
  shutdown,
}

///|
test "processors receive independent span snapshots" {
  let trace_hex = "0102030405060708090a0b0c0d0e0f10"
  let span_hex = "1112131415161718"
  let parent_hex = "2122232425262728"
  let parent = @api.span_context(
    @api.bytes_from_hex(trace_hex).unwrap(),
    @api.bytes_from_hex(parent_hex).unwrap(),
    @api.TRACE_FLAGS_SAMPLED,
  )
  let observer = IsolationObserverProcessor::new(trace_hex, span_hex, parent_hex)
  let provider = @sdk.TracerProviderSdk::new(service_name="snapshot-isolation")
    .with_span_processor(IsolationMutatingProcessor::new())
    .with_span_processor(observer)
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("snapshot-isolation")
  let span = tracer.start_span(
    "op",
    parent~,
    links=[
      @sdk.SpanLink::new(
        parent,
        attributes=Map([("link", @sdk.StringValue("kept"))]),
      ),
    ],
  )
  observer.expected_span_id.val = span.context().span_id_hex()
  span.set_attribute("kept", @sdk.IntValue(7L))
  span.add_event(
    "event",
    attributes=Map([("event", @sdk.StringValue("kept"))]),
  )
  span.end()
  if observer.failures.length() != 0 {
    abort("processor snapshots were shared: " + observer.failures.join("; "))
  }
  // The ended span's accessors use the stored snapshot, not a processor copy.
  assert_eq(span.attributes().get("injected"), None)
  assert_eq(span.attributes().get("kept"), Some(@sdk.IntValue(7L)))
  assert_eq(span.events()[0].attributes.get("injected"), None)
  assert_eq(span.links()[0].attributes.get("injected"), None)
  assert_eq(span.context().trace_id_hex(), trace_hex)
  assert_eq(span.context().span_id_hex(), observer.expected_span_id.val)
  assert_eq(@api.bytes_to_hex(span.parent_span_id()), parent_hex)
  provider.shutdown()
}
