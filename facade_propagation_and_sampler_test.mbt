// Facade coverage for propagation header names, tracestate parsing and
// sampling-decision constructors.

///|
test "facade_exposes_w3c_header_names" {
  assert_eq(@otel.traceparent_header_name(), "traceparent")
  assert_eq(@otel.tracestate_header_name(), "tracestate")
  assert_eq(@otel.baggage_header_name(), "baggage")
}

///|
test "facade_parse_tracestate_normalizes" {
  assert_eq(@otel.parse_tracestate("a=1 , b=2"), Some("a=1,b=2"))
  assert_eq(@otel.parse_tracestate("bad key=value"), None)
}

///|
test "facade_sampling_decision_constructors" {
  let sampled = @otel.sampling_decision_record_and_sample()
  assert_true(sampled.is_recorded)
  assert_true(sampled.is_sampled)
  let record_only = @otel.sampling_decision_record_only()
  assert_true(record_only.is_recorded)
  assert_false(record_only.is_sampled)
  let dropped = @otel.sampling_decision_drop()
  assert_false(dropped.is_recorded)
  assert_false(dropped.is_sampled)
}

///|
test "facade_sampling_decision_drives_custom_sampler" {
  @otel.shutdown_global_tracer_provider()
  let provider = @otel.setup(
    service_name="facade-custom-sampler",
    sampler=@otel.Sampler::new("FacadeDrop", fn(_parameters) {
      @otel.sampling_decision_drop()
    }),
  )
  let tracer = @otel.global_tracer("facade-sampler-scope")
  let span = tracer.start_root_span("dropped")
  assert_false(span.is_recording())
  span.end()
  provider.shutdown()
  @otel.shutdown_global_tracer_provider()
}
