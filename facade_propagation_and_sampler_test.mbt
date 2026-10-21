// Facade coverage for propagation header names, tracestate parsing and
// sampling-decision constructors.

///|
test "facade_exposes_w3c_header_names" {
  assert_eq(@moonotel.traceparent_header_name(), "traceparent")
  assert_eq(@moonotel.tracestate_header_name(), "tracestate")
  assert_eq(@moonotel.baggage_header_name(), "baggage")
}

///|
test "facade_parse_tracestate_normalizes" {
  assert_eq(@moonotel.parse_tracestate("a=1 , b=2"), Some("a=1,b=2"))
  assert_eq(@moonotel.parse_tracestate("bad key=value"), None)
}

///|
test "facade_sampling_decision_constructors" {
  let sampled = @moonotel.sampling_decision_record_and_sample()
  assert_true(sampled.is_recorded)
  assert_true(sampled.is_sampled)
  let record_only = @moonotel.sampling_decision_record_only()
  assert_true(record_only.is_recorded)
  assert_false(record_only.is_sampled)
  let dropped = @moonotel.sampling_decision_drop()
  assert_false(dropped.is_recorded)
  assert_false(dropped.is_sampled)
}

///|
test "facade_sampling_decision_drives_custom_sampler" {
  @moonotel.shutdown_global_tracer_provider()
  let provider = @moonotel.setup(
    service_name="facade-custom-sampler",
    sampler=@moonotel.Sampler::new("FacadeDrop", fn(_parameters) {
      @moonotel.sampling_decision_drop()
    }),
  )
  let tracer = @moonotel.global_tracer("facade-sampler-scope")
  let span = tracer.start_root_span("dropped")
  assert_false(span.is_recording())
  span.end()
  provider.shutdown()
  @moonotel.shutdown_global_tracer_provider()
}
