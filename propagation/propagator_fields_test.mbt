///|
struct FieldProbe {
  names : Array[String]
}

///|
pub impl @propagation.TextMapPropagator for FieldProbe with fn inject(
  self,
  _context,
  _carrier,
) {
  let _ = self
}

///|
pub impl @propagation.TextMapPropagator for FieldProbe with fn extract(
  self,
  _carrier,
) {
  let _ = self
  @context.Context::root()
}

///|
pub impl @propagation.TextMapPropagator for FieldProbe with fn fields(self) {
  self.names
}

///|
struct LegacyFieldProbe {}

///|
pub impl @propagation.TextMapPropagator for LegacyFieldProbe with fn inject(
  self,
  _context,
  _carrier,
) {
  let _ = self
}

///|
pub impl @propagation.TextMapPropagator for LegacyFieldProbe with fn extract(
  self,
  _carrier,
) {
  let _ = self
  @context.Context::root()
}

///|
test "builtin_propagators_report_their_header_fields" {
  assert_eq(@propagation.TraceContextPropagator::new().fields(), [
    "traceparent", "tracestate",
  ])
  assert_eq(@propagation.BaggagePropagator::new().fields(), ["baggage"])
}

///|
test "composite_propagator_fields_follow_member_order_without_duplicates" {
  let composite = @propagation.CompositePropagator::new([
    @propagation.BaggagePropagator::new(),
    @propagation.TraceContextPropagator::new(),
    @propagation.BaggagePropagator::new(),
  ])
  assert_eq(composite.fields(), ["baggage", "traceparent", "tracestate"])
}

///|
test "composite_propagator_fields_deduplicate_ignoring_case" {
  let composite = @propagation.CompositePropagator::new([
    FieldProbe::{ names: ["X-Custom"], },
    @propagation.BaggagePropagator::new(),
    FieldProbe::{ names: ["x-custom", "Baggage"], },
  ])
  assert_eq(composite.fields(), ["X-Custom", "baggage"])
}

///|
test "custom_propagators_without_fields_report_none" {
  let legacy : &@propagation.TextMapPropagator = LegacyFieldProbe::{ }
  assert_eq(legacy.fields(), [])
  let composite = @propagation.CompositePropagator::new([legacy])
  assert_eq(composite.fields(), [])
}

///|
test "global_propagator_fields_reflect_the_environment_selection" {
  @propagation.reset_global_propagator()
  defer @propagation.reset_global_propagator()
  @env.unset_env_var("OTEL_PROPAGATORS")
  assert_eq(@propagation.global_propagator().fields(), [
    "traceparent", "tracestate", "baggage",
  ])
  @env.set_env_var("OTEL_PROPAGATORS", "none")
  defer @env.unset_env_var("OTEL_PROPAGATORS")
  @propagation.reset_global_propagator()
  assert_eq(@propagation.global_propagator().fields(), [])
}
