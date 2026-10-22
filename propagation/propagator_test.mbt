// Tests for text-map propagators: the trace context and baggage propagators,
// the composite propagator and the `OTEL_PROPAGATORS` environment handling.

///|
fn propagator_span() -> @api.SpanContext {
  @api.span_context(
    [
      0x4b, 0xf9, 0x2f, 0x35, 0x9d, 0x1e, 0x75, 0xb7, 0x61, 0x8a, 0x2d, 0x1f, 0x3c,
      0x4e, 0x5a, 0x6b,
    ],
    [0x00, 0xf0, 0x67, 0xaa, 0x0b, 0xa9, 0x02, 0xb7],
    @api.TRACE_FLAGS_SAMPLED,
    tracestate="congo=t61rcWkgMzE",
  )
}

// A propagator that writes a fixed marker header and turns it into a baggage
// value on extraction, used to observe composite ordering.

///|
struct MarkerPropagator {
  header : String
}

///|
pub impl @propagation.TextMapPropagator for MarkerPropagator with fn inject(
  self,
  _context,
  carrier,
) {
  carrier.set(self.header, self.header)
}

///|
pub impl @propagation.TextMapPropagator for MarkerPropagator with fn extract(
  self,
  carrier,
) {
  match carrier.get(self.header) {
    Some(value) => @context.Context::root().with_value("marker", value)
    None => @context.Context::root()
  }
}

// A propagator whose extracted context explicitly removes the `marker` key,
// leaving no visible baggage of its own.

///|
struct DeletionPropagator {}

///|
pub impl @propagation.TextMapPropagator for DeletionPropagator with fn inject(
  self,
  _context,
  _carrier,
) {
  let _ = self
}

///|
pub impl @propagation.TextMapPropagator for DeletionPropagator with fn extract(
  self,
  _carrier,
) {
  let _ = self
  @context.Context::root()
  .with_value("marker", "temporary")
  .without_value("marker")
}

///|
test "trace_context_propagator_round_trip" {
  let propagator = @propagation.TraceContextPropagator::new()
  let context = @context.Context::root()
    .with_span(propagator_span())
    .with_value("user.id", "42")
  let carrier = @propagation.TextMapCarrier::new()
  propagator.inject(context, carrier)
  assert_eq(
    carrier.get("traceparent"),
    Some("00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"),
  )
  assert_eq(carrier.get("tracestate"), Some("congo=t61rcWkgMzE"))
  // The trace context propagator does not touch baggage.
  assert_true(carrier.get("baggage") is None)
  let extracted = propagator.extract(carrier)
  let span = extracted.span_context().unwrap()
  assert_eq(span.trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
  assert_eq(span.span_id_hex(), "00f067aa0ba902b7")
  assert_eq(span.tracestate(), "congo=t61rcWkgMzE")
  assert_true(span.is_remote())
  assert_false(extracted.has_baggage())
}

///|
test "trace_context_propagator_extracts_invalid_traceparent_as_root" {
  let propagator = @propagation.TraceContextPropagator::new()
  let carrier = @propagation.TextMapCarrier::from_entries([
    ("traceparent", "00-00000000000000000000000000000000-0000000000000000-01"),
  ])
  let context = propagator.extract(carrier)
  assert_true(context.span_context() is None)
}

///|
test "baggage_propagator_round_trip" {
  let propagator = @propagation.BaggagePropagator::new()
  let context = @context.Context::root().with_value("user.id", "42")
  let carrier = @propagation.TextMapCarrier::new()
  propagator.inject(context, carrier)
  // The baggage propagator does not touch the trace headers.
  assert_true(carrier.get("traceparent") is None)
  assert_eq(carrier.get("baggage"), Some("user.id=42"))
  let extracted = propagator.extract(carrier)
  assert_true(extracted.span_context() is None)
  assert_eq(extracted.value("user.id"), Some("42"))
}

///|
test "composite_propagator_round_trips_trace_context_and_baggage" {
  let composite = @propagation.CompositePropagator::new([
    @propagation.TraceContextPropagator::new(),
    @propagation.BaggagePropagator::new(),
  ])
  assert_eq(composite.length(), 2)
  let context = @context.Context::root()
    .with_span(propagator_span())
    .with_value("tenant", "acme")
  let carrier = @propagation.TextMapCarrier::new()
  composite.inject(context, carrier)
  assert_true(carrier.get("traceparent") is Some(_))
  assert_eq(carrier.get("baggage"), Some("tenant=acme"))
  let extracted = composite.extract(carrier)
  assert_eq(extracted.span_context().unwrap().span_id_hex(), "00f067aa0ba902b7")
  assert_eq(extracted.value("tenant"), Some("acme"))
}

///|
test "composite_propagator_runs_members_in_order" {
  let composite = @propagation.CompositePropagator::new([
    MarkerPropagator::{ header: "first", },
    MarkerPropagator::{ header: "second", },
  ])
  let carrier = @propagation.TextMapCarrier::new()
  composite.inject(@context.Context::root(), carrier)
  assert_eq(carrier.get("first"), Some("first"))
  assert_eq(carrier.get("second"), Some("second"))
  // Extraction folds the member contexts; the last member wins.
  let extracted = composite.extract(carrier)
  assert_eq(extracted.value("marker"), Some("second"))
}

///|
test "composite_propagator_honors_baggage_removal_from_later_members" {
  let composite = @propagation.CompositePropagator::new([
    MarkerPropagator::{ header: "first", },
    DeletionPropagator::{},
  ])
  let carrier = @propagation.TextMapCarrier::new()
  carrier.set("first", "from-marker")
  let extracted = composite.extract(carrier)
  // The later propagator has no visible baggage, but its removal marker must
  // still hide the value extracted by the earlier member.
  assert_eq(extracted.value("marker"), None)
  assert_false(extracted.has_baggage())
}

///|
test "empty_composite_propagator_is_a_no_op" {
  let composite = @propagation.CompositePropagator::new([])
  assert_eq(composite.length(), 0)
  let carrier = @propagation.TextMapCarrier::new()
  composite.inject(
    @context.Context::root()
    .with_span(propagator_span())
    .with_value("user.id", "42"),
    carrier,
  )
  assert_eq(carrier.length(), 0)
  let extracted = composite.extract(carrier)
  assert_true(extracted.span_context() is None)
  assert_false(extracted.has_baggage())
}

///|
fn clear_propagators_env() -> Unit {
  @env.unset_env_var("OTEL_PROPAGATORS")
}

///|
test "propagator_from_env_defaults_to_tracecontext_and_baggage" {
  clear_propagators_env()
  let composite = @propagation.CompositePropagator::from_env()
  assert_eq(composite.length(), 2)
  let carrier = @propagation.TextMapCarrier::new()
  composite.inject(
    @context.Context::root()
    .with_span(propagator_span())
    .with_value("user.id", "42"),
    carrier,
  )
  assert_true(carrier.get("traceparent") is Some(_))
  assert_true(carrier.get("baggage") is Some(_))
  clear_propagators_env()
}

///|
test "propagator_from_env_reads_single_propagators" {
  clear_propagators_env()
  @env.set_env_var("OTEL_PROPAGATORS", "tracecontext")
  let trace_only = @propagation.CompositePropagator::from_env()
  @env.set_env_var("OTEL_PROPAGATORS", "baggage")
  let baggage_only = @propagation.CompositePropagator::from_env()
  clear_propagators_env()
  assert_eq(trace_only.length(), 1)
  assert_eq(baggage_only.length(), 1)
  let carrier = @propagation.TextMapCarrier::new()
  baggage_only.inject(
    @context.Context::root().with_value("user.id", "42"),
    carrier,
  )
  assert_true(carrier.get("traceparent") is None)
  assert_true(carrier.get("baggage") is Some(_))
}

///|
test "propagator_from_env_none_disables_propagation" {
  clear_propagators_env()
  @env.set_env_var("OTEL_PROPAGATORS", "none")
  let composite = @propagation.CompositePropagator::from_env()
  clear_propagators_env()
  assert_eq(composite.length(), 0)
  let carrier = @propagation.TextMapCarrier::new()
  composite.inject(
    @context.Context::root().with_span(propagator_span()),
    carrier,
  )
  assert_eq(carrier.length(), 0)
}

///|
test "propagator_from_env_ignores_unknown_names" {
  clear_propagators_env()
  @env.set_env_var("OTEL_PROPAGATORS", "b3, xray ,tracecontext")
  let composite = @propagation.CompositePropagator::from_env()
  clear_propagators_env()
  assert_eq(composite.length(), 1)
  let carrier = @propagation.TextMapCarrier::new()
  composite.inject(
    @context.Context::root()
    .with_span(propagator_span())
    .with_value("user.id", "42"),
    carrier,
  )
  assert_true(carrier.get("traceparent") is Some(_))
  assert_true(carrier.get("baggage") is None)
}

///|
test "propagator_from_env_is_case_insensitive_and_deduplicates" {
  clear_propagators_env()
  @env.set_env_var("OTEL_PROPAGATORS", "TraceContext, tracecontext, BAGGAGE")
  let composite = @propagation.CompositePropagator::from_env()
  clear_propagators_env()
  assert_eq(composite.length(), 2)
}

///|
test "propagator_from_env_blank_value_uses_the_default" {
  clear_propagators_env()
  @env.set_env_var("OTEL_PROPAGATORS", "  ")
  let composite = @propagation.CompositePropagator::from_env()
  clear_propagators_env()
  assert_eq(composite.length(), 2)
}

///|
test "propagator_from_env_extracts_the_configured_headers" {
  clear_propagators_env()
  @env.set_env_var("OTEL_PROPAGATORS", "tracecontext,baggage")
  let composite = @propagation.CompositePropagator::from_env()
  clear_propagators_env()
  let carrier = @propagation.TextMapCarrier::from_entries([
    ("traceparent", "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"),
    ("tracestate", "congo=t61rcWkgMzE"),
    ("baggage", "user.id=42"),
  ])
  let context = composite.extract(carrier)
  let span = context.span_context().unwrap()
  assert_eq(span.trace_id_hex(), "4bf92f359d1e75b7618a2d1f3c4e5a6b")
  assert_eq(span.tracestate(), "congo=t61rcWkgMzE")
  assert_eq(context.value("user.id"), Some("42"))
}
