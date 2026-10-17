// Blackbox tests for the SDK tracer, spans, and processors.

struct RecordingExporter {
  spans : Array[@sdk.SpanData]
  mut shutdown_called : Bool
}

fn recording_exporter() -> RecordingExporter {
  { spans: [], shutdown_called: false }
}

pub impl @sdk.SpanExporter for RecordingExporter with export_spans(self, spans) {
  for span in spans {
    self.spans.push(span)
  }
  @sdk.ExportSuccess
}

pub impl @sdk.SpanExporter for RecordingExporter with shutdown(self) {
  self.shutdown_called = true
}

test "span_shape_and_context" {
  let exporter = recording_exporter()
  let provider = @sdk.TracerProviderSdk::new(service_name="test-service")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("test-scope", version="1.0.0")
  let span = tracer.start_root_span(
    "operation",
    start_time_unix_nano=100,
  )
  assert_true(span.is_recording())
  assert_true(span.context().is_valid())
  assert_true(span.context().is_sampled())
  assert_eq(span.context().trace_id_hex().length(), 32)
  assert_eq(span.context().span_id_hex().length(), 16)
  assert_eq(span.name(), "operation")
  assert_eq(span.parent_span_id().length(), 0)
  assert_eq(span.kind(), @api.SpanKind::Internal)
  span.end(end_time_unix_nano=200)
  assert_true(span.is_ended())
  assert_eq(exporter.spans.length(), 1)
  let data = exporter.spans[0]
  assert_eq(data.name, "operation")
  assert_eq(data.start_time_unix_nano, 100L)
  assert_eq(data.end_time_unix_nano, 200L)
  assert_eq(data.scope_name, "test-scope")
  assert_eq(data.scope_version, "1.0.0")
  assert_eq(data.status, @api.StatusCode::Unset)
  assert_eq(data.resource.get(@sdk.SERVICE_NAME), Some(@sdk.StringValue("test-service")))
}

test "end_is_idempotent" {
  let exporter = recording_exporter()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let span = provider.get_tracer("t").start_root_span("op")
  span.end(end_time_unix_nano=10L)
  span.end(end_time_unix_nano=20L)
  assert_eq(exporter.spans.length(), 1)
  assert_eq(exporter.spans[0].end_time_unix_nano, 10L)
}

test "child_span_joins_parent_trace" {
  let exporter = recording_exporter()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("t")
  let parent = tracer.start_root_span("parent")
  let child = tracer.start_span("child", parent=parent.context())
  assert_eq(child.context().trace_id_hex(), parent.context().trace_id_hex())
  assert_true(child.context().span_id_hex() != parent.context().span_id_hex())
  assert_eq(child.parent_span_id().length(), 8)
  assert_eq(
    @api.bytes_to_hex(child.parent_span_id()),
    parent.context().span_id_hex(),
  )
}

test "invalid_parent_is_ignored" {
  let exporter = recording_exporter()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("t")
  let span = tracer.start_span("op", parent=@api.invalid_span_context())
  assert_eq(span.parent_span_id().length(), 0)
}

test "sampling_off_drops_span" {
  let exporter = recording_exporter()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_off())
  let span = provider.get_tracer("t").start_root_span("op")
  assert_false(span.is_recording())
  assert_false(span.context().is_sampled())
  span.set_attribute("key", @sdk.StringValue("value"))
  span.add_event("event")
  assert_eq(span.attributes().length(), 0)
  assert_eq(span.events().length(), 0)
  span.end()
  assert_eq(exporter.spans.length(), 0)
}

test "attributes_events_and_status" {
  let exporter = recording_exporter()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("t")
  let attributes : Map[String, @sdk.AttributeValue] = Map::new()
  attributes.set("http.request.method", @sdk.StringValue("GET"))
  attributes.set("http.response.status_code", @sdk.IntValue(200L))
  let span = tracer.start_root_span(
    "GET /",
    kind=@api.SpanKind::Server,
    attributes=attributes,
  )
  span.set_attribute("custom.bool", @sdk.BoolValue(true))
  span.set_attribute("custom.double", @sdk.DoubleValue(1.5))
  span.add_event("retry", time_unix_nano=1234L)
  span.set_status(@api.StatusCode::Ok)
  span.update_name("GET /users")
  span.end(end_time_unix_nano=4000L)
  let data = exporter.spans[0]
  assert_eq(data.kind, @api.SpanKind::Server)
  assert_eq(data.name, "GET /users")
  assert_eq(data.attributes.length(), 4)
  assert_eq(data.attributes.get("http.request.method"), Some(@sdk.StringValue("GET")))
  assert_eq(data.events.length(), 1)
  assert_eq(data.events[0].name, "retry")
  assert_eq(data.events[0].time_unix_nano, 1234L)
  assert_eq(data.status, @api.StatusCode::Ok)
}

test "attribute_setters_are_noops_after_end" {
  let exporter = recording_exporter()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let span = provider.get_tracer("t").start_root_span("op")
  span.end()
  span.set_attribute("late", @sdk.StringValue("x"))
  span.update_name("late")
  span.add_event("late")
  span.set_status(@api.StatusCode::Error)
  assert_eq(exporter.spans[0].name, "op")
  assert_eq(exporter.spans[0].attributes.length(), 0)
  assert_eq(exporter.spans[0].events.length(), 0)
  assert_eq(exporter.spans[0].status, @api.StatusCode::Unset)
}

test "simple_processor_stops_after_shutdown" {
  let exporter = recording_exporter()
  let processor = @sdk.SimpleSpanProcessor::new(exporter)
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(processor)
  let span = provider.get_tracer("t").start_root_span("op")
  provider.shutdown()
  assert_true(processor.is_shutdown())
  assert_true(exporter.shutdown_called)
  span.end()
  assert_eq(exporter.spans.length(), 0)
  provider.shutdown()
}

test "batch_processor_flushes_at_threshold" {
  let exporter = recording_exporter()
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=10,
    max_export_batch_size=3,
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(processor)
  let tracer = provider.get_tracer("t")
  for i = 0; i < 2; i = i + 1 {
    tracer.start_root_span("op-" + i.to_string()).end()
  }
  assert_eq(processor.queue_size(), 2)
  assert_eq(exporter.spans.length(), 0)
  tracer.start_root_span("op-2").end()
  assert_eq(processor.queue_size(), 0)
  assert_eq(exporter.spans.length(), 3)
}

test "batch_processor_drops_oldest_when_full" {
  let exporter = recording_exporter()
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=2,
    max_export_batch_size=100,
  )
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(processor)
  let tracer = provider.get_tracer("t")
  tracer.start_root_span("op-0").end()
  tracer.start_root_span("op-1").end()
  tracer.start_root_span("op-2").end()
  assert_eq(processor.queue_size(), 2)
  provider.force_flush()
  assert_eq(exporter.spans.length(), 2)
  assert_eq(exporter.spans[0].name, "op-1")
  assert_eq(exporter.spans[1].name, "op-2")
}

test "batch_processor_shutdown_flushes" {
  let exporter = recording_exporter()
  let processor = @sdk.BatchSpanProcessor::new(exporter, max_export_batch_size=100)
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(processor)
  provider.get_tracer("t").start_root_span("op").end()
  assert_eq(exporter.spans.length(), 0)
  provider.shutdown()
  assert_eq(exporter.spans.length(), 1)
  assert_true(exporter.shutdown_called)
  assert_true(processor.is_shutdown())
}

test "global_provider_round_trip" {
  @sdk.shutdown_global_tracer_provider()
  assert_true(@sdk.global_tracer_provider() is None)
  let provider = @sdk.TracerProviderSdk::new(service_name="global-svc")
  @sdk.set_global_tracer_provider(provider)
  assert_true(@sdk.global_tracer_provider() is Some(_))
  let tracer = @sdk.global_tracer("global-scope")
  assert_eq(tracer.scope_name(), "global-scope")
  @sdk.shutdown_global_tracer_provider()
  assert_true(@sdk.global_tracer_provider() is None)
}

test "id_generator_random_ids" {
  let generator = @sdk.IdGenerator::random()
  let trace_id = generator.generate_trace_id()
  let span_id = generator.generate_span_id()
  assert_eq(trace_id.length(), 16)
  assert_eq(span_id.length(), 8)
  assert_false(@api.is_zero(trace_id))
  assert_false(@api.is_zero(span_id))
  let next_trace_id = generator.generate_trace_id()
  assert_true(@api.bytes_to_hex(trace_id) != @api.bytes_to_hex(next_trace_id))
}

test "id_generator_deterministic" {
  let a = @sdk.IdGenerator::deterministic(42)
  let b = @sdk.IdGenerator::deterministic(42)
  assert_eq(
    @api.bytes_to_hex(a.generate_trace_id()),
    @api.bytes_to_hex(b.generate_trace_id()),
  )
  assert_eq(
    @api.bytes_to_hex(a.generate_span_id()),
    @api.bytes_to_hex(b.generate_span_id()),
  )
}

test "provider_resource_and_sampler_accessors" {
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_resource_attribute(@sdk.SERVICE_VERSION, @sdk.StringValue("2.3.4"))
  assert_eq(provider.resource().get(@sdk.SERVICE_NAME), Some(@sdk.StringValue("svc")))
  assert_eq(provider.resource().get(@sdk.SERVICE_VERSION), Some(@sdk.StringValue("2.3.4")))
  let decision = provider.sampler().should_sample(None, @api.bytes_from_hex("0102030405060708090a0b0c0d0e0f10").unwrap())
  assert_true(decision.is_sampled)
}

test "span_stops_recording_once_ended" {
  let exporter = recording_exporter()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("t")
  let span = tracer.start_root_span("op")
  assert_true(span.is_recording())
  span.end(end_time_unix_nano=100L)
  assert_false(span.is_recording())
  assert_true(span.is_ended())
}

test "span_stays_non_recording_after_second_end" {
  let exporter = recording_exporter()
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_off())
  let span = provider.get_tracer("t").start_root_span("op")
  assert_false(span.is_recording())
  span.end(end_time_unix_nano=1L)
  span.end(end_time_unix_nano=2L)
  assert_false(span.is_recording())
  assert_eq(exporter.spans.length(), 0)
}
