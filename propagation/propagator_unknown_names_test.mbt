// `OTEL_PROPAGATORS` values containing only unsupported names are ignored as
// an invalid setting, so propagation keeps the documented default instead of
// silently turning into a no-op.

///|
test "propagator_from_env_falls_back_when_every_name_is_unknown" {
  @env.unset_env_var("OTEL_PROPAGATORS")
  defer @env.unset_env_var("OTEL_PROPAGATORS")
  @env.set_env_var("OTEL_PROPAGATORS", "b3,xray")
  let composite = @propagation.CompositePropagator::from_env()
  assert_eq(composite.length(), 2)
  let carrier = @propagation.TextMapCarrier::new()
  composite.inject(
    @context.Context::root()
    .with_span(
      @api.span_context(
        @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
        @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
        1,
      ),
    )
    .with_value("user.id", "42"),
    carrier,
  )
  assert_true(carrier.get("traceparent") is Some(_))
  assert_true(carrier.get("baggage") is Some(_))
}

///|
test "propagator_from_env_none_still_disables_unknown_names" {
  @env.unset_env_var("OTEL_PROPAGATORS")
  defer @env.unset_env_var("OTEL_PROPAGATORS")
  @env.set_env_var("OTEL_PROPAGATORS", "b3,none")
  let composite = @propagation.CompositePropagator::from_env()
  assert_eq(composite.length(), 0)
}

///|
test "propagator_from_env_unknown_names_do_not_hide_known_ones" {
  @env.unset_env_var("OTEL_PROPAGATORS")
  defer @env.unset_env_var("OTEL_PROPAGATORS")
  @env.set_env_var("OTEL_PROPAGATORS", "b3,baggage")
  let composite = @propagation.CompositePropagator::from_env()
  assert_eq(composite.length(), 1)
  let carrier = @propagation.TextMapCarrier::new()
  composite.inject(
    @context.Context::root()
    .with_span(
      @api.span_context(
        @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
        @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
        1,
      ),
    )
    .with_value("user.id", "42"),
    carrier,
  )
  assert_true(carrier.get("traceparent") is None)
  assert_true(carrier.get("baggage") is Some(_))
}
