// Context-level propagation.
//
// A carrier usually transports the W3C trace context together with W3C
// baggage, so instrumentations need a single call that reads or writes both.
// `inject_context` and `extract_context` are those entry points; they compose
// the `traceparent`/`tracestate` propagator with the `baggage` propagator.

// Inject the trace context and the baggage carried by `context` into
// `carrier`. A context without a valid span propagates only its baggage.
pub fn inject_context(
  context : @context.Context,
  carrier : TextMapCarrier
) -> Unit {
  match context.span_context() {
    Some(sc) => inject(sc, carrier)
    None => ()
  }
  inject_baggage(context, carrier)
}

// Extract a context from `carrier`: the W3C trace context when present and
// valid, plus every valid baggage member. Returns the root context when the
// carrier carries neither.
pub fn extract_context(carrier : TextMapCarrier) -> @context.Context {
  let mut context = extract_baggage_context(carrier)
  match extract(carrier) {
    Some(sc) => context = context.with_span(sc)
    None => ()
  }
  context
}
