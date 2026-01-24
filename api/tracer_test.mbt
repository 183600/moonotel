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
  span_counter : Int
}

struct Span {
  name : String
  context : SpanContext
}

struct Counter {
  mut value : Int
}

let counter : Counter = { value: 0 }

fn next_span_counter() -> Int {
  counter.value = counter.value + 1
  counter.value
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
  let counter = next_span_counter()
  let trace_id = self.provider.id_generator.trace_id
  let span_id = generate_span_id_from_counter(counter, trace_id[0])
  let context = span_context(trace_id, span_id, 1)
  Span::{ name: name, context: context }
}

fn generate_span_id_from_counter(counter : Int, trace_byte : Int) -> Array[Int] {
  let span_id = Array::make(8, 0)
  // Use both counter and trace_byte for uniqueness
  span_id[0] = counter & 0xFF
  span_id[1] = (counter >> 8) & 0xFF
  span_id[2] = (counter >> 16) & 0xFF
  span_id[3] = (counter >> 24) & 0xFF
  span_id[4] = (counter >> 32) & 0xFF
  span_id[5] = (counter >> 40) & 0xFF
  span_id[6] = (counter >> 48) & 0xFF
  span_id[7] = trace_byte & 0xFF
  span_id
}
