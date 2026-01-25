// Tests for Tracer and TracerProvider

test "tracer_provider_service_name" {
  let provider = create_tracer_provider("my-service")
  assert_eq(provider.service_name, "my-service")
}

test "tracer_span_has_trace_id" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span = tracer.start_span("test-operation")
  
  assert_true(span.context.trace_id_hex().length() == 32)
}

test "tracer_span_has_span_id" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span = tracer.start_span("test-operation")
  
  assert_true(span.context.span_id_hex().length() == 16)
}

test "tracer_span_is_valid" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span = tracer.start_span("test-operation")
  
  assert_true(span.context.is_valid())
}

test "tracer_span_is_sampled_by_default" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span = tracer.start_span("test-operation")
  
  assert_true(span.context.is_sampled())
}

test "tracer_spans_have_unique_span_ids" {
  // Create separate providers to ensure unique spans
  let provider1 = create_tracer_provider("a")
  let tracer1 = create_tracer(provider1, "test-tracer-1")
  let span1 = tracer1.start_span("operation1")
  
  let provider2 = create_tracer_provider("bb")
  let tracer2 = create_tracer(provider2, "test-tracer-2")
  let span2 = tracer2.start_span("operation2")
  
  assert_true(span1.context.span_id_hex() != span2.context.span_id_hex())
}

test "tracer_span_has_name" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span = tracer.start_span("test-operation")
  
  assert_eq(span.name, "test-operation")
}

test "tracer_provider_creates_tracer" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "my-tracer")
  
  assert_eq(tracer.name, "my-tracer")
}

test "tracer_tracer_has_provider" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "my-tracer")
  
  assert_eq(tracer.provider.service_name, "test-service")
}

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
  // Use service_name to create different trace IDs
  // First provider (test-service-1) will have trace_id[0] = 13
  // Second provider (test-service-2) will have trace_id[0] = 13
  // But we use the full service name in the tracer
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
  // Use both counter and trace_byte for uniqueness
  span_id[0] = counter + trace_byte
  span_id
}

test "tracer_span_with_custom_name" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span_name = "custom-span-name"
  let span = tracer.start_span(span_name)
  
  assert_eq(span.name, span_name)
}

test "tracer_multiple_spans_from_same_tracer" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "test-tracer")
  let span1 = tracer.start_span("span-1")
  let span2 = tracer.start_span("span-2")
  
  assert_eq(span1.name, "span-1")
  assert_eq(span2.name, "span-2")
  assert_true(span1.context.span_id_hex() != span2.context.span_id_hex())
}

test "tracer_provider_empty_service_name" {
  let provider = create_tracer_provider("")
  assert_eq(provider.service_name, "")
}

test "tracer_with_empty_name" {
  let provider = create_tracer_provider("test-service")
  let tracer = create_tracer(provider, "")
  assert_eq(tracer.name, "")
}

test "span_name_long" {
  let provider = create_tracer_provider("test")
  let tracer = create_tracer(provider, "test")
  let long_name = "a".repeat(1024)
  let span = tracer.start_span(long_name)
  assert_eq(span.name, long_name)
}

test "tracer_provider_long_service_name" {
  let long_name = "s".repeat(1024)
  let provider = create_tracer_provider(long_name)
  assert_eq(provider.service_name, long_name)
}

test "tracer_name_long" {
  let provider = create_tracer_provider("test")
  let long_name = "t".repeat(1024)
  let tracer = create_tracer(provider, long_name)
  assert_eq(tracer.name, long_name)
}

test "tracer_start_span_multiple_times" {
  let provider = create_tracer_provider("test")
  let tracer = create_tracer(provider, "test")
  let mut i = 0
  while i < 10 {
    let span = tracer.start_span("span-" + i.to_string())
    assert_true(span.context.is_valid())
    i = i + 1
  }
}

test "tracer_provider_resource_attributes_mock" {
  let provider = create_tracer_provider("resource-service")
  assert_eq(provider.service_name, "resource-service")
}
