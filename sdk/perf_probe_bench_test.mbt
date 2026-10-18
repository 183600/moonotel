// Micro-benchmarks for the SDK hot paths (run with `moon bench`).

test "bench span lifecycle" (b : @bench.T) {
  let provider = @sdk.TracerProviderSdk::new(service_name="bench")
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("bench")
  b.bench(fn() {
    let span = tracer.start_span("op", kind=@api.SpanKind::Internal)
    span.set_attribute("http.method", @sdk.StringValue("GET"))
    span.set_attribute("http.status", @sdk.IntValue(200L))
    span.set_attribute("http.long", @sdk.StringValue("some longer value 1234567890"))
    span.end()
  })
}

test "bench span lifecycle with exporter" (b : @bench.T) {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="bench")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("bench")
  b.bench(fn() {
    let span = tracer.start_span("op")
    span.set_attribute("k", @sdk.StringValue("v"))
    span.end()
  })
}

test "bench encode batch" (b : @bench.T) {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="bench")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("bench", version="1.0.0")
  for i = 0; i < 100; i = i + 1 {
    let span = tracer.start_span("operation")
    span.set_attribute("index", @sdk.IntValue(i.to_int64()))
    span.set_attribute("name", @sdk.StringValue("value-\{i}"))
    span.end()
  }
  let spans = exporter.exported_spans()
  b.bench(fn() {
    let _ = @otlp.encode_trace_request(spans)
  })
}

test "bench traceparent roundtrip" (b : @bench.T) {
  let sc = @api.span_context(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    [1, 2, 3, 4, 5, 6, 7, 8],
    1,
  )
  b.bench(fn() {
    let tp = @propagation.format_traceparent(sc)
    let _ = @propagation.parse_traceparent(tp)
  })
}

test "bench bytes_to_hex" (b : @bench.T) {
  let bytes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  b.bench(fn() {
    let _ = @api.bytes_to_hex(bytes)
  })
}

test "bench context chain" (b : @bench.T) {
  let mut ctx = @context.Context::root()
  for i = 0; i < 16; i = i + 1 {
    ctx = ctx.with_value("key-\{i}", "value-\{i}")
  }
  b.bench(fn() {
    let _ = ctx.value("key-15")
    let _ = ctx.value("key-0")
    let _ = ctx.value("missing")
  })
}

test "bench tracestate parse" (b : @bench.T) {
  let value = "vendor1=value1,vendor2=value2,vendor3=value3"
  b.bench(fn() {
    let _ = @propagation.parse_tracestate(value)
  })
}

test "bench baggage format parse" (b : @bench.T) {
  let entries : Array[(String, String)] = [
    ("key1", "value1"),
    ("key2", "value2"),
    ("key3", "value3"),
  ]
  b.bench(fn() {
    let formatted = @propagation.format_baggage(entries)
    let _ = @propagation.parse_baggage(formatted)
  })
}

test "bench encode batch no attrs" (b : @bench.T) {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="bench")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("bench", version="1.0.0")
  for i = 0; i < 100; i = i + 1 {
    let span = tracer.start_span("operation")
    span.end()
  }
  let spans = exporter.exported_spans()
  b.bench(fn() {
    let _ = @otlp.encode_trace_request(spans)
  })
}

test "bench encode single span" (b : @bench.T) {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="bench")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("bench", version="1.0.0")
  let span = tracer.start_span("operation")
  span.set_attribute("index", @sdk.IntValue(3L))
  span.set_attribute("name", @sdk.StringValue("value-3"))
  span.end()
  let spans = exporter.exported_spans()
  b.bench(fn() {
    let _ = @otlp.encode_trace_request(spans)
  })
}

test "bench id generation" (b : @bench.T) {
  let gen = @sdk.IdGenerator::random()
  b.bench(fn() {
    let _ = gen.generate_trace_id()
    let _ = gen.generate_span_id()
  })
}

test "bench span start only" (b : @bench.T) {
  let provider = @sdk.TracerProviderSdk::new(service_name="bench")
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("bench")
  b.bench(fn() {
    let span = tracer.start_span("op")
    b.keep(span)
  })
}

test "bench env now" (b : @bench.T) {
  b.bench(fn() {
    let _ = @env.now()
  })
}

test "bench span context construction" (b : @bench.T) {
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  b.bench(fn() {
    let sc = @api.span_context(trace_id, span_id, 1)
    b.keep(sc)
  })
}

test "bench sampler always on" (b : @bench.T) {
  let sampler = @sdk.Sampler::always_on()
  let trace_id = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  b.bench(fn() {
    let d = sampler.should_sample(None, trace_id)
    b.keep(d)
  })
}

test "bench span end only" (b : @bench.T) {
  let provider = @sdk.TracerProviderSdk::new(service_name="bench")
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("bench")
  b.bench(fn() {
    let span = tracer.start_span("op")
    span.end()
  })
}

test "bench span set attributes" (b : @bench.T) {
  let provider = @sdk.TracerProviderSdk::new(service_name="bench")
    .with_sampler(@sdk.Sampler::always_on())
  let tracer = provider.get_tracer("bench")
  let span = tracer.start_span("op")
  b.bench(fn() {
    span.set_attribute("http.method", @sdk.StringValue("GET"))
  })
}

test "bench bytes_from_hex" (b : @bench.T) {
  b.bench(fn() {
    let _ = @api.bytes_from_hex("0102030405060708090a0b0c0d0e0f10")
  })
}

test "bench span_context_from_hex" (b : @bench.T) {
  b.bench(fn() {
    let _ = @api.span_context_from_hex(
      "0102030405060708090a0b0c0d0e0f10",
      "0102030405060708",
      1,
    )
  })
}

test "bench format traceparent" (b : @bench.T) {
  let sc = @api.span_context(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    [1, 2, 3, 4, 5, 6, 7, 8],
    1,
  )
  b.bench(fn() {
    let _ = @propagation.format_traceparent(sc)
  })
}

test "bench parse traceparent" (b : @bench.T) {
  b.bench(fn() {
    let _ = @propagation.parse_traceparent(
      "00-0102030405060708090a0b0c0d0e0f10-0102030405060708-01",
    )
  })
}

test "bench encode single span no attrs" (b : @bench.T) {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="bench")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("bench", version="1.0.0")
  let span = tracer.start_span("operation")
  span.end()
  let spans = exporter.exported_spans()
  b.bench(fn() {
    let _ = @otlp.encode_trace_request(spans)
  })
}

test "bench encode single span one attr" (b : @bench.T) {
  let exporter = @sdk.InMemorySpanExporter::new()
  let provider = @sdk.TracerProviderSdk::new(service_name="bench")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
  let tracer = provider.get_tracer("bench", version="1.0.0")
  let span = tracer.start_span("operation")
  span.set_attribute("index", @sdk.IntValue(3L))
  span.end()
  let spans = exporter.exported_spans()
  b.bench(fn() {
    let _ = @otlp.encode_trace_request(spans)
  })
}

test "bench baggage format only" (b : @bench.T) {
  let entries : Array[(String, String)] = [
    ("key1", "value1"),
    ("key2", "value2"),
    ("key3", "value3"),
  ]
  b.bench(fn() {
    let _ = @propagation.format_baggage(entries)
  })
}

test "bench baggage parse only" (b : @bench.T) {
  b.bench(fn() {
    let _ = @propagation.parse_baggage("key1=value1,key2=value2,key3=value3")
  })
}

test "bench context baggage header" (b : @bench.T) {
  let mut ctx = @context.Context::root()
  for i = 0; i < 3; i = i + 1 {
    ctx = ctx.with_value("key-\{i}", "value-\{i}")
  }
  b.bench(fn() {
    let _ = @propagation.context_baggage_header(ctx)
  })
}
