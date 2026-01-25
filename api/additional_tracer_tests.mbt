// Additional tracer-related tests

// Helper types and functions for tracer tests
struct Tracer {
  name : String
  provider : TracerProvider
}

struct TracerProvider {
  service_name : String
  id_generator : IdGenerator
}

struct IdGenerator {
  trace_id : Array[Int]
  mut span_counter : Int
}

struct Span {
  name : String
  context : SpanContext
}

fn create_tracer_provider(service_name : String) -> TracerProvider {
  TracerProvider::{ service_name: service_name, id_generator: IdGenerator::{ trace_id: Array::make(16, service_name.length()), span_counter: 0 } }
}

fn create_tracer(provider : TracerProvider, name : String) -> Tracer {
  Tracer::{ name: name, provider: provider }
}

pub fn Tracer::start_span(self : Tracer, name : String) -> Span {
  self.provider.id_generator.span_counter = self.provider.id_generator.span_counter + 1
  let counter = self.provider.id_generator.span_counter
  let trace_id = self.provider.id_generator.trace_id
  let span_id = generate_span_id_from_counter(counter, trace_id[0])
  let context = span_context(trace_id, span_id, 1)
  Span::{ name: name, context: context }
}

fn generate_span_id_from_counter(counter : Int, trace_byte : Int) -> Array[Int] {
  let span_id = Array::make(8, 0)
  span_id[0] = counter + trace_byte
  span_id
}

test "tracer_provider_with_empty_service_name" {
  let provider = create_tracer_provider("")
  assert_eq(provider.service_name, "")
}

test "tracer_provider_with_long_service_name" {
  let long_name = "this-is-a-very-long-service-name-that-might-exceed-normal-lengths"
  let provider = create_tracer_provider(long_name)
  assert_eq(provider.service_name, long_name)
}

test "tracer_with_empty_name" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "")
  assert_eq(tracer.name, "")
}

test "tracer_span_with_empty_name" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span = tracer.start_span("")
  assert_eq(span.name, "")
}

test "tracer_multiple_spans_have_unique_span_ids" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  
  let span1 = tracer.start_span("operation1")
  let span2 = tracer.start_span("operation2")
  let span3 = tracer.start_span("operation3")
  
  assert_true(span1.context.span_id_hex() != span2.context.span_id_hex())
  assert_true(span2.context.span_id_hex() != span3.context.span_id_hex())
  assert_true(span1.context.span_id_hex() != span3.context.span_id_hex())
}

test "tracer_spans_have_same_trace_id" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  
  let span1 = tracer.start_span("operation1")
  let span2 = tracer.start_span("operation2")
  
  assert_eq(span1.context.trace_id_hex(), span2.context.trace_id_hex())
}

test "tracer_span_is_sampled_flag" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span = tracer.start_span("test-operation")
  
  assert_true(span.context.is_sampled())
}

test "tracer_context_validity" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span = tracer.start_span("test-operation")
  
  assert_true(span.context.is_valid())
}

test "tracer_span_hex_formats" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span = tracer.start_span("test-operation")
  
  // Trace ID should be 32 hex characters
  assert_eq(span.context.trace_id_hex().length(), 32)
  // Span ID should be 16 hex characters
  assert_eq(span.context.span_id_hex().length(), 16)
}

test "tracer_service_name_with_special_chars" {
  let name_with_special = "service.name_with-special.chars"
  let provider = create_tracer_provider(name_with_special)
  assert_eq(provider.service_name, name_with_special)
}

test "tracer_with_numeric_name" {
  let provider = create_tracer_provider("service-123")
  let tracer = create_tracer(provider, "tracer-456")
  assert_eq(tracer.name, "tracer-456")
  assert_eq(tracer.provider.service_name, "service-123")
}
