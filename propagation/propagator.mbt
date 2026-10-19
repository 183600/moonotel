// Text-map propagators.
//
// A `TextMapPropagator` reads and writes the trace context and baggage of a
// `Context` from and to a text carrier such as HTTP headers or message
// metadata. `TraceContextPropagator` handles the W3C `traceparent` and
// `tracestate` headers, `BaggagePropagator` handles the W3C `baggage` header,
// and `CompositePropagator` runs several propagators in order.
//
// `CompositePropagator::from_env` builds a composite from the standard
// `OTEL_PROPAGATORS` environment variable, mirroring the other `from_env`
// configuration points of the SDK.

// A propagator that injects and extracts a `Context` through a text carrier.

///|
pub(open) trait TextMapPropagator {
  fn inject(Self, @context.Context, TextMapCarrier) -> Unit
  fn extract(Self, TextMapCarrier) -> @context.Context
}

// The W3C Trace Context propagator, handling `traceparent` and `tracestate`.

///|
pub struct TraceContextPropagator {}

// Create a W3C Trace Context propagator.

///|
pub fn TraceContextPropagator::new() -> TraceContextPropagator {
  TraceContextPropagator::{ }
}

///|
pub impl TextMapPropagator for TraceContextPropagator with fn inject(
  self,
  context,
  carrier,
) {
  let _ = self
  match context.span_context() {
    Some(sc) => inject(sc, carrier)
    None => ()
  }
}

///|
pub impl TextMapPropagator for TraceContextPropagator with fn extract(
  self,
  carrier,
) {
  let _ = self
  match extract(carrier) {
    Some(sc) => @context.Context::root().with_span(sc)
    None => @context.Context::root()
  }
}

///|
pub extend TraceContextPropagator with TextMapPropagator::{inject, extract}

// The W3C Baggage propagator, handling the `baggage` header.

///|
pub struct BaggagePropagator {}

// Create a W3C Baggage propagator.

///|
pub fn BaggagePropagator::new() -> BaggagePropagator {
  BaggagePropagator::{ }
}

///|
pub impl TextMapPropagator for BaggagePropagator with fn inject(
  self,
  context,
  carrier,
) {
  let _ = self
  inject_baggage(context, carrier)
}

///|
pub impl TextMapPropagator for BaggagePropagator with fn extract(self, carrier) {
  let _ = self
  extract_baggage_context(carrier)
}

///|
pub extend BaggagePropagator with TextMapPropagator::{inject, extract}

// A propagator that runs a list of propagators in order. Injection writes
// with every member in list order; extraction folds the contexts returned by
// every member into one context (later members win for the same key).

///|
pub struct CompositePropagator {
  propagators : Array[&TextMapPropagator]
}

// Create a composite propagator from the given members. The array is stored
// as given; callers must not mutate it afterwards.

///|
pub fn CompositePropagator::new(
  propagators : Array[&TextMapPropagator],
) -> CompositePropagator {
  { propagators, }
}

// Number of member propagators.

///|
pub fn CompositePropagator::length(self : CompositePropagator) -> Int32 {
  self.propagators.length()
}

///|
pub impl TextMapPropagator for CompositePropagator with fn inject(
  self,
  context,
  carrier,
) {
  for propagator in self.propagators {
    propagator.inject(context, carrier)
  }
}

///|
pub impl TextMapPropagator for CompositePropagator with fn extract(
  self,
  carrier,
) {
  let mut context = @context.Context::root()
  for propagator in self.propagators {
    let extracted = propagator.extract(carrier)
    // Flatten the baggage only when there is any, and hand the resulting map
    // to the context.
    if extracted.has_baggage() {
      context = context.with_baggage_owned(extracted.baggage())
    }
    match extracted.span_context() {
      Some(sc) => context = context.with_span(sc)
      None => ()
    }
  }
  context
}

///|
pub extend CompositePropagator with TextMapPropagator::{inject, extract}

// Build a composite propagator from `OTEL_PROPAGATORS`, a comma-separated
// list of propagator names. Unset or blank values select the default
// `tracecontext,baggage`; `none` disables propagation; unknown names are
// ignored. Names are matched case-insensitively and duplicates (including
// `none` alongside other names) are reduced to their first occurrence.

///|
pub fn CompositePropagator::from_env() -> CompositePropagator {
  let names : Array[String] = []
  match @env.get_env_var("OTEL_PROPAGATORS") {
    Some(value) =>
      for item in value.split(",") {
        let name = item.trim().to_lower().to_owned()
        if name != "" {
          names.push(name)
        }
      }
    None => ()
  }
  if names.length() == 0 {
    names.push("tracecontext")
    names.push("baggage")
  }
  let propagators : Array[&TextMapPropagator] = []
  let mut has_trace_context = false
  let mut has_baggage = false
  for name in names {
    match name {
      "none" => return CompositePropagator::new([])
      "tracecontext" =>
        if !has_trace_context {
          has_trace_context = true
          let created : &TextMapPropagator = TraceContextPropagator::new()
          propagators.push(created)
        }
      "baggage" =>
        if !has_baggage {
          has_baggage = true
          let created : &TextMapPropagator = BaggagePropagator::new()
          propagators.push(created)
        }
      _ => ()
    }
  }
  CompositePropagator::new(propagators)
}

// Process-wide propagator installed with `set_global_propagator`. The default
// propagator is stored in the same slot.

///|
let global_propagator_slot : Ref[&TextMapPropagator?] = Ref(None)

// Install a process-wide `TextMapPropagator`. Instrumentations resolve the
// propagator they use through `global_propagator`, so this is the one place to
// change how context crosses process boundaries. The installed propagator
// takes precedence over `OTEL_PROPAGATORS` until `reset_global_propagator` is
// called.

///|
pub fn set_global_propagator(propagator : &TextMapPropagator) -> Unit {
  global_propagator_slot.val = Some(propagator)
}

// The process-wide `TextMapPropagator`. When none has been installed the
// composite selected by `OTEL_PROPAGATORS` (`tracecontext,baggage` by default)
// is built on first use.

///|
pub fn global_propagator() -> &TextMapPropagator {
  match global_propagator_slot.val {
    Some(propagator) => propagator
    None => {
      let propagator : &TextMapPropagator = CompositePropagator::from_env()
      global_propagator_slot.val = Some(propagator)
      propagator
    }
  }
}

// Forget the installed or default propagator so that the next
// `global_propagator` call reads `OTEL_PROPAGATORS` again. Intended for tests
// and for processes that re-initialize their configuration.

///|
pub fn reset_global_propagator() -> Unit {
  global_propagator_slot.val = None
}
