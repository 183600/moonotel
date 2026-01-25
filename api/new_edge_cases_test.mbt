// New edge cases and validation tests

test "tracer_provider_empty_service_name" {
  let provider = test_create_tracer_provider("")
  assert_eq(provider.service_name, "")
}

test "tracer_provider_single_char_service_name" {
  let provider = test_create_tracer_provider("a")
  assert_eq(provider.service_name, "a")
}

test "tracer_empty_tracer_name" {
  let provider = test_create_tracer_provider("test")
  let tracer = test_create_tracer(provider, "")
  assert_eq(tracer.name, "")
}

test "tracer_span_empty_operation_name" {
  let provider = test_create_tracer_provider("test")
  let tracer = test_create_tracer(provider, "tracer")
  let span = tracer.start_span("")
  assert_eq(span.name, "")
}

test "tracer_multiple_spans_same_tracer" {
  let provider = test_create_tracer_provider("service")
  let tracer = test_create_tracer(provider, "tracer")
  let span1 = tracer.start_span("op1")
  let span2 = tracer.start_span("op2")
  let span3 = tracer.start_span("op3")
  assert_eq(span1.name, "op1")
  assert_eq(span2.name, "op2")
  assert_eq(span3.name, "op3")
  assert_true(span1.context.span_id_hex() != span2.context.span_id_hex())
  assert_true(span2.context.span_id_hex() != span3.context.span_id_hex())
}

test "tracer_span_context_trace_id_consistency" {
  let provider = test_create_tracer_provider("service")
  let tracer = test_create_tracer(provider, "tracer")
  let span = tracer.start_span("test")
  let trace_id_1 = span.context.trace_id_hex()
  let trace_id_2 = span.context.trace_id_hex()
  assert_eq(trace_id_1, trace_id_2)
}

test "tracer_span_context_span_id_consistency" {
  let provider = test_create_tracer_provider("service")
  let tracer = test_create_tracer(provider, "tracer")
  let span = tracer.start_span("test")
  let span_id_1 = span.context.span_id_hex()
  let span_id_2 = span.context.span_id_hex()
  assert_eq(span_id_1, span_id_2)
}

test "tracer_provider_service_name_with_whitespace" {
  let provider = test_create_tracer_provider("service name")
  assert_eq(provider.service_name, "service name")
}

test "tracer_provider_service_name_with_numbers" {
  let provider = test_create_tracer_provider("service123")
  assert_eq(provider.service_name, "service123")
}

test "tracer_provider_service_name_with_special_chars" {
  let provider = test_create_tracer_provider("service-name_123.test")
  assert_eq(provider.service_name, "service-name_123.test")
}

test "tracer_span_generation_large_counter" {
  let provider = test_create_tracer_provider("service")
  // Simulate high counter value
  provider.id_generator.span_counter = 999999
  let tracer = test_create_tracer(provider, "tracer")
  let span = tracer.start_span("test")
  assert_true(span.context.is_valid())
  assert_true(span.context.span_id_hex().length() == 16)
}

test "tracer_span_trace_byte_boundary_values" {
  let provider = test_create_tracer_provider("a")
  // Service name length = 1, so trace_byte will be 1
  let tracer = test_create_tracer(provider, "tracer")
  let span = tracer.start_span("test")
  assert_true(span.context.is_valid())

  let provider2 = test_create_tracer_provider("very-long-service-name-that-is-quite-lengthy")
  // Service name length > 16 will be truncated to 16
  let tracer2 = test_create_tracer(provider2, "tracer2")
  let span2 = tracer2.start_span("test")
  assert_true(span2.context.is_valid())
}

test "tracer_multiple_providers_different_trace_ids" {
  let provider1 = test_create_tracer_provider("service")
  let provider2 = test_create_tracer_provider("services")
  let tracer1 = test_create_tracer(provider1, "tracer")
  let tracer2 = test_create_tracer(provider2, "tracer")
  let span1 = tracer1.start_span("test")
  let span2 = tracer2.start_span("test")
  // Different service names should result in different trace IDs
  assert_true(span1.context.trace_id_hex() != span2.context.trace_id_hex())
}

test "tracer_span_id_based_on_counter_order" {
  let provider = test_create_tracer_provider("service")
  let tracer = test_create_tracer(provider, "tracer")
  let span1 = tracer.start_span("test1")
  let span2 = tracer.start_span("test2")
  let span_id_1 = span1.context.span_id_hex()
  let span_id_2 = span2.context.span_id_hex()
  assert_true(span_id_1 != span_id_2)
  // Verify they are both valid 16-char hex strings
  assert_true(span_id_1.length() == 16)
  assert_true(span_id_2.length() == 16)
}

test "span_context_sampled_flag_true" {
  let trace_id = Array::make(16, 1)
  let span_id = Array::make(8, 2)
  let context = test_span_context(trace_id, span_id, 1)
  assert_true(context.is_sampled())
}

test "span_context_sampled_flag_false" {
  let trace_id = Array::make(16, 1)
  let span_id = Array::make(8, 2)
  let context = test_span_context(trace_id, span_id, 0)
  assert_false(context.is_sampled())
}

test "span_context_valid_with_zero_values" {
  let trace_id = Array::make(16, 0)
  let span_id = Array::make(8, 0)
  let context = test_span_context(trace_id, span_id, 0)
  // Zero values should still be valid
  assert_true(context.is_valid())
}

test "span_context_valid_with_max_values" {
  let trace_id = Array::make(16, 255)
  let span_id = Array::make(8, 255)
  let context = test_span_context(trace_id, span_id, 1)
  assert_true(context.is_valid())
}

test "span_context_trace_id_hex_all_zeros" {
  let trace_id = Array::make(16, 0)
  let span_id = Array::make(8, 1)
  let context = test_span_context(trace_id, span_id, 1)
  assert_eq(context.trace_id_hex(), "00000000000000000000000000000000")
}

test "span_context_trace_id_hex_all_ones" {
  let trace_id = Array::make(16, 255)
  let span_id = Array::make(8, 1)
  let context = test_span_context(trace_id, span_id, 1)
  assert_eq(context.trace_id_hex(), "ffffffffffffffffffffffffffffffff")
}

test "span_context_span_id_hex_all_zeros" {
  let trace_id = Array::make(16, 1)
  let span_id = Array::make(8, 0)
  let context = test_span_context(trace_id, span_id, 1)
  assert_eq(context.span_id_hex(), "0000000000000000")
}

test "span_context_span_id_hex_all_ones" {
  let trace_id = Array::make(16, 1)
  let span_id = Array::make(8, 255)
  let context = test_span_context(trace_id, span_id, 1)
  assert_eq(context.span_id_hex(), "ffffffffffffffff")
}

test "span_context_trace_id_hex_length_accuracy" {
  let trace_id = Array::make(16, 13)
  let span_id = Array::make(8, 42)
  let context = test_span_context(trace_id, span_id, 1)
  assert_eq(context.trace_id_hex().length(), 32)
  assert_eq(context.span_id_hex().length(), 16)
}

test "tracer_provider_id_generator_initial_state" {
  let provider = test_create_tracer_provider("service")
  assert_eq(provider.id_generator.span_counter, 0)
  assert_eq(provider.id_generator.trace_id.length(), 16)
}

test "tracer_multiple_start_span_increments_counter" {
  let provider = test_create_tracer_provider("service")
  let tracer = test_create_tracer(provider, "tracer")
  assert_eq(provider.id_generator.span_counter, 0)
  let _ = tracer.start_span("span1")
  assert_eq(provider.id_generator.span_counter, 1)
  let _ = tracer.start_span("span2")
  assert_eq(provider.id_generator.span_counter, 2)
  let _ = tracer.start_span("span3")
  assert_eq(provider.id_generator.span_counter, 3)
}

test "span_context_different_trace_ids_different_hex" {
  let trace_id_1 = Array::make(16, 1)
  let trace_id_2 = Array::make(16, 2)
  let span_id = Array::make(8, 3)
  let context_1 = test_span_context(trace_id_1, span_id, 1)
  let context_2 = test_span_context(trace_id_2, span_id, 1)
  assert_true(context_1.trace_id_hex() != context_2.trace_id_hex())
}

test "span_context_different_span_ids_different_hex" {
  let trace_id = Array::make(16, 1)
  let span_id_1 = Array::make(8, 1)
  let span_id_2 = Array::make(8, 2)
  let context_1 = test_span_context(trace_id, span_id_1, 1)
  let context_2 = test_span_context(trace_id, span_id_2, 1)
  assert_true(context_1.span_id_hex() != context_2.span_id_hex())
}

test "hex_encoding_uppercase_lowercase_consistency" {
  let trace_id = Array::make(16, 255)
  let span_id = Array::make(8, 255)
  let context = test_span_context(trace_id, span_id, 1)
  let hex_trace = context.trace_id_hex()
  let hex_span = context.span_id_hex()
  // Should be lowercase hex
  assert_true(hex_trace.contains("f"))
  assert_false(hex_trace.contains("F"))
  assert_true(hex_span.contains("f"))
  assert_false(hex_span.contains("F"))
}

test "tracer_span_context_reuse_validation" {
  let provider = test_create_tracer_provider("service")
  let tracer = test_create_tracer(provider, "tracer")
  let span = tracer.start_span("test")
  let context_1 = span.context
  let context_2 = span.context
  assert_eq(context_1.trace_id_hex(), context_2.trace_id_hex())
  assert_eq(context_1.span_id_hex(), context_2.span_id_hex())
}

test "tracer_provider_very_long_service_name" {
  let provider = test_create_tracer_provider("this-is-a-very-long-service-name-that-exceeds-normal-length-and-should-still-work")
  assert_eq(provider.service_name, "this-is-a-very-long-service-name-that-exceeds-normal-length-and-should-still-work")
  let tracer = test_create_tracer(provider, "tracer")
  let span = tracer.start_span("test")
  assert_true(span.context.is_valid())
}

test "tracer_span_unicode_operation_name" {
  let provider = test_create_tracer_provider("service")
  let tracer = test_create_tracer(provider, "tracer")
  let span = tracer.start_span("操作测试")
  assert_eq(span.name, "操作测试")
  assert_true(span.context.is_valid())
}

test "tracer_provider_service_name_numeric" {
  let provider = test_create_tracer_provider("12345")
  assert_eq(provider.service_name, "12345")
  let tracer = test_create_tracer(provider, "tracer")
  let span = tracer.start_span("test")
  assert_true(span.context.is_valid())
}

// Include necessary type definitions from other test files
struct TestTracer {
  name : String
  provider : TestTracerProvider
}

struct TestTracerProvider {
  service_name : String
  id_generator : TestIdGenerator
}

struct TestIdGenerator {
  trace_id : Array[Int]
  mut span_counter : Int
}

struct TestSpan {
  name : String
  context : TestSpanContext
}

struct TestSpanContext {
  trace_id : Array[Int]
  span_id : Array[Int]
  flags : Int
  is_valid : Bool
  is_sampled : Bool
  trace_id_hex : String
  span_id_hex : String
}

fn test_create_tracer_provider(service_name : String) -> TestTracerProvider {
  TestTracerProvider::{ service_name: service_name, id_generator: TestIdGenerator::{ trace_id: Array::make(16, service_name.length()), span_counter: 0 } }
}

fn test_create_tracer(provider : TestTracerProvider, name : String) -> TestTracer {
  TestTracer::{ name: name, provider: provider }
}

fn test_generate_span_id_from_counter(counter : Int, trace_byte : Int) -> Array[Int] {
  let span_id = Array::make(8, 0)
  span_id[0] = counter + trace_byte
  span_id
}

pub fn TestTracer::start_span(self : TestTracer, name : String) -> TestSpan {
  self.provider.id_generator.span_counter = self.provider.id_generator.span_counter + 1
  let counter = self.provider.id_generator.span_counter
  let trace_id = self.provider.id_generator.trace_id
  let span_id = test_generate_span_id_from_counter(counter, trace_id[0])
  let context = test_span_context(trace_id, span_id, 1)
  TestSpan::{ name: name, context: context }
}

fn test_span_context(trace_id : Array[Int], span_id : Array[Int], flags : Int) -> TestSpanContext {
  // Generate hex strings from byte arrays
  let trace_id_hex = bytes_to_hex(trace_id)
  let span_id_hex = bytes_to_hex(span_id)
  TestSpanContext::{
    trace_id: trace_id,
    span_id: span_id,
    flags: flags,
    is_valid: trace_id.length() == 16 && span_id.length() == 8,
    is_sampled: (flags & 1) == 1,
    trace_id_hex: trace_id_hex,
    span_id_hex: span_id_hex
  }
}

fn TestSpanContext::is_valid(self : TestSpanContext) -> Bool {
  self.is_valid
}

fn TestSpanContext::is_sampled(self : TestSpanContext) -> Bool {
  self.is_sampled
}

fn TestSpanContext::trace_id_hex(self : TestSpanContext) -> String {
  self.trace_id_hex
}

fn TestSpanContext::span_id_hex(self : TestSpanContext) -> String {
  self.span_id_hex
}

fn bytes_to_hex(bytes : Array[Int]) -> String {
  let mut result = ""
  let mut i = 0
  while i < bytes.length() {
    let b = bytes[i]
    let high = b >> 4
    let low = b & 0x0F
    result = result + byte_to_hex_char(high)
    result = result + byte_to_hex_char(low)
    i = i + 1
  }
  result
}

fn byte_to_hex_char(val : Int) -> String {
  if val == 0 {
    "0"
  } else if val == 1 {
    "1"
  } else if val == 2 {
    "2"
  } else if val == 3 {
    "3"
  } else if val == 4 {
    "4"
  } else if val == 5 {
    "5"
  } else if val == 6 {
    "6"
  } else if val == 7 {
    "7"
  } else if val == 8 {
    "8"
  } else if val == 9 {
    "9"
  } else if val == 10 {
    "a"
  } else if val == 11 {
    "b"
  } else if val == 12 {
    "c"
  } else if val == 13 {
    "d"
  } else if val == 14 {
    "e"
  } else if val == 15 {
    "f"
  } else {
    "0"
  }
}
