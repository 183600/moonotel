// Facade tests for the re-exported text-map propagators and the global
// force-flush helper.

fn facade_propagator_span() -> @otel.SpanContext {
  @otel.span_context(
    @otel.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
    @otel.bytes_from_hex("00f067aa0ba902b7").unwrap(),
    1,
    tracestate="congo=t61rcWkgMzE",
  )
}

test "facade_composite_propagator_from_env_round_trip" {
  @env.unset_env_var("OTEL_PROPAGATORS")
  let composite = @otel.CompositePropagator::from_env()
  assert_eq(composite.length(), 2)
  let context = @otel.Context::root()
    .with_span(facade_propagator_span())
    .with_value("user.id", "42")
  let carrier = @otel.TextMapCarrier::new()
  composite.inject(context, carrier)
  assert_eq(
    carrier.get("traceparent"),
    Some("00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"),
  )
  assert_eq(carrier.get("tracestate"), Some("congo=t61rcWkgMzE"))
  assert_eq(carrier.get("baggage"), Some("user.id=42"))
  let extracted = composite.extract(carrier)
  assert_eq(
    extracted.span_context().unwrap().trace_id_hex(),
    "4bf92f359d1e75b7618a2d1f3c4e5a6b",
  )
  assert_eq(extracted.value("user.id"), Some("42"))
}

test "facade_propagator_types_are_constructible" {
  let trace : &@otel.TextMapPropagator = @otel.TraceContextPropagator::new()
  let baggage : &@otel.TextMapPropagator = @otel.BaggagePropagator::new()
  let composite = @otel.CompositePropagator::new([trace, baggage])
  assert_eq(composite.length(), 2)
}

test "force_flush_global_tracer_provider_drains_batch_processor" {
  @otel.shutdown_global_tracer_provider()
  let capture = capturing_transport()
  let provider = @otel.setup(
    service_name="global-flush",
    endpoint="http://collector:4318",
    transport=capture.send(),
    batch=@sdk.BatchConfig::new(
      max_queue_size=8,
      max_export_batch_size=8,
      flush_interval_millis=0,
    ),
  )
  let _ = provider
  let tracer = @otel.global_tracer("global-flush")
  tracer.start_root_span("queued").end()
  assert_eq(capture.urls.length(), 0)
  @otel.force_flush_global_tracer_provider()
  assert_eq(capture.urls.length(), 1)
  // Calling force flush again exports nothing more.
  @otel.force_flush_global_tracer_provider()
  assert_eq(capture.urls.length(), 1)
  @otel.shutdown_global_tracer_provider()
}

test "force_flush_global_tracer_provider_without_a_provider_is_a_no_op" {
  @otel.shutdown_global_tracer_provider()
  @otel.force_flush_global_tracer_provider()
  assert_true(@otel.global_tracer_provider() is None)
}
