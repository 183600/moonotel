// `yourname/otel` is the main entry package. It re-exports the API, SDK,
// propagation and OTLP exporter surface and offers a one-call initializer.

///|
pub using @api {
  type SpanContext,
  type SpanKind,
  type StatusCode,
  invalid_span_context,
  span_context,
  span_context_from_hex,
  bytes_to_hex,
  bytes_from_hex,
  TRACE_FLAGS_SAMPLED,
}

///|
pub using @sdk {
  type AttributeValue,
  type SpanData,
  type SpanEvent,
  type SpanLink,
  type SamplingDecision,
  type ExportResult,
  type Sampler,
  type SpanLimits,
  type IdGenerator,
  type SpanSdk,
  type Tracer,
  type TracerProviderSdk,
  type SimpleSpanProcessor,
  type BatchSpanProcessor,
  trait SpanProcessor,
  trait SpanExporter,
  global_tracer,
  global_tracer_provider,
  set_global_tracer_provider,
  shutdown_global_tracer_provider,
  SDK_VERSION,
  TELEMETRY_SDK_NAME,
  TELEMETRY_SDK_LANGUAGE,
  TELEMETRY_SDK_VERSION,
}

///|
pub using @context {
  type Context,
  current_context,
  current_span_context,
  attach,
  detach,
  with_context,
  with_span_context,
}

///|
pub using @propagation {
  type TextMapCarrier,
  inject,
  extract,
  inject_context,
  extract_context,
  format_traceparent,
  parse_traceparent,
  extract_tracestate,
  inject_with_tracestate,
  baggage_header_name,
  context_baggage_header,
  inject_baggage,
  extract_baggage,
  extract_baggage_context,
  parse_baggage,
  format_baggage,
}

///|
pub using @otlp {
  type OtlpHttpConfig,
  type OtlpHttpExporter,
  type Transport,
  type TransportResponse,
  decode_export_response,
  encode_trace_request,
}

// One-call setup: build a TracerProvider, optionally wire an OTLP/HTTP
// batch exporter with the supplied transport function, and install it as the
// process-wide provider.
//
// `endpoint` and `headers` override the values read from the
// OTEL_EXPORTER_OTLP_* environment variables. `resource_attributes` are
// merged into the resource built from the environment, and `span_limits`
// replaces the limits read from the OTEL_SPAN_* environment variables.

///|
pub fn setup(
  service_name? : String,
  resource_attributes? : Map[String, @sdk.AttributeValue],
  endpoint? : String,
  headers? : Map[String, String],
  sampler? : @sdk.Sampler,
  span_limits? : @sdk.SpanLimits,
  transport? : @otlp.Transport,
  use_batch? : Bool,
) -> @sdk.TracerProviderSdk {
  let mut provider = @sdk.TracerProviderSdk::new(service_name?)
  match resource_attributes {
    Some(values) => provider = provider.with_resource_attributes(values)
    None => ()
  }
  match sampler {
    Some(value) => provider = provider.with_sampler(value)
    None => ()
  }
  match span_limits {
    Some(value) => provider = provider.with_span_limits(value)
    None => ()
  }
  match transport {
    Some(send) => {
      let base = @otlp.OtlpHttpConfig::from_env()
      let config : @otlp.OtlpHttpConfig = {
        ..base,
        endpoint: endpoint.unwrap_or(base.endpoint),
        traces_endpoint: match endpoint {
          Some(_) => None
          None => base.traces_endpoint
        },
        headers: headers.unwrap_or(base.headers),
      }
      let exporter = @otlp.OtlpHttpExporter::new(config, send)
      let batch = use_batch.unwrap_or(true)
      let processor : &@sdk.SpanProcessor = if batch {
        // Queue/batch/interval defaults come from the OTEL_BSP_* variables.
        let value : &@sdk.SpanProcessor = @sdk.BatchSpanProcessor::from_env(
          exporter,
        )
        value
      } else {
        let value : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(
          exporter,
        )
        value
      }
      provider = provider.with_span_processor(processor)
    }
    None => ()
  }
  @sdk.set_global_tracer_provider(provider)
  provider
}
