// Blackbox tests for the process-wide propagator registry.

///|
fn global_propagator_span() -> @api.SpanContext {
  @api.span_context(
    [
      0x4b, 0xf9, 0x2f, 0x35, 0x9d, 0x1e, 0x75, 0xb7, 0x61, 0x8a, 0x2d, 0x1f, 0x3c,
      0x4e, 0x5a, 0x6b,
    ],
    [0x00, 0xf0, 0x67, 0xaa, 0x0b, 0xa9, 0x02, 0xb7],
    @api.TRACE_FLAGS_SAMPLED,
  )
}

///|
fn global_propagator_context() -> @context.Context {
  @context.Context::root()
  .with_span(global_propagator_span())
  .with_value("user.id", "42")
}

///|
test "global_propagator_defaults_to_env_selection" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  @env.set_env_var("OTEL_PROPAGATORS", "tracecontext")
  defer @env.unset_env_var("OTEL_PROPAGATORS")
  let propagator = @propagation.global_propagator()
  let carrier = @propagation.TextMapCarrier::new()
  propagator.inject(global_propagator_context(), carrier)
  assert_true(carrier.get("traceparent") is Some(_))
  assert_true(carrier.get("baggage") is None)
  let extracted = propagator.extract(carrier)
  assert_true(extracted.span_context() is Some(_))
  assert_false(extracted.has_baggage())
}

///|
test "global_propagator_default_includes_baggage" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  @env.unset_env_var("OTEL_PROPAGATORS")
  let propagator = @propagation.global_propagator()
  let carrier = @propagation.TextMapCarrier::new()
  propagator.inject(global_propagator_context(), carrier)
  assert_true(carrier.get("traceparent") is Some(_))
  assert_true(carrier.get("baggage") is Some(_))
  let extracted = propagator.extract(carrier)
  assert_true(extracted.span_context() is Some(_))
  assert_true(extracted.has_baggage())
}

///|
test "global_propagator_none_disables_propagation" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  @env.set_env_var("OTEL_PROPAGATORS", "none")
  defer @env.unset_env_var("OTEL_PROPAGATORS")
  let propagator = @propagation.global_propagator()
  let carrier = @propagation.TextMapCarrier::new()
  propagator.inject(global_propagator_context(), carrier)
  assert_eq(carrier.length(), 0)
  let incoming = @propagation.TextMapCarrier::new()
  incoming.set(
    "traceparent",
    @propagation.format_traceparent(global_propagator_span()),
  )
  incoming.set("baggage", "user.id=42")
  let extracted = propagator.extract(incoming)
  assert_true(extracted.span_context() is None)
  assert_false(extracted.has_baggage())
}

///|
test "set_global_propagator_overrides_the_environment" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  @env.set_env_var("OTEL_PROPAGATORS", "none")
  defer @env.unset_env_var("OTEL_PROPAGATORS")
  let baggage_only : &@propagation.TextMapPropagator = @propagation.BaggagePropagator::new()
  @propagation.set_global_propagator(baggage_only)
  let propagator = @propagation.global_propagator()
  let carrier = @propagation.TextMapCarrier::new()
  propagator.inject(global_propagator_context(), carrier)
  assert_eq(carrier.length(), 1)
  assert_true(carrier.get("baggage") is Some(_))
  assert_true(carrier.get("traceparent") is None)
}

///|
test "reset_global_propagator_rereads_the_environment" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  @env.unset_env_var("OTEL_PROPAGATORS")
  // Trigger the lazy default (`tracecontext,baggage`) so that it is cached.
  let first_carrier = @propagation.TextMapCarrier::new()
  @propagation.global_propagator().inject(global_propagator_context(), first_carrier)
  assert_true(first_carrier.get("traceparent") is Some(_))
  @env.set_env_var("OTEL_PROPAGATORS", "none")
  defer @env.unset_env_var("OTEL_PROPAGATORS")
  // The cached propagator keeps the old selection...
  let carrier = @propagation.TextMapCarrier::new()
  @propagation.global_propagator().inject(global_propagator_context(), carrier)
  assert_true(carrier.get("traceparent") is Some(_))
  // ... until it is reset.
  @propagation.reset_global_propagator()
  let none_carrier = @propagation.TextMapCarrier::new()
  @propagation.global_propagator().inject(
    global_propagator_context(),
    none_carrier,
  )
  assert_eq(none_carrier.length(), 0)
}
