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
  type SamplingParameters,
  type ExportResult,
  type Sampler,
  type SpanLimits,
  type IdGenerator,
  type Resource,
  type SpanSdk,
  type Tracer,
  type TracerProviderSdk,
  type SimpleSpanProcessor,
  type BatchSpanProcessor,
  type BatchConfig,
  type InMemorySpanExporter,
  type ConsoleSpanExporter,
  trait SpanProcessor,
  trait SpanExporter,
  global_tracer,
  global_tracer_provider,
  set_global_tracer_provider,
  shutdown_global_tracer_provider,
  force_flush_global_tracer_provider,
  traces_exporter_enabled,
  exporter_selected,
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
  type Tracestate,
  trait TextMapPropagator,
  type TraceContextPropagator,
  type BaggagePropagator,
  type CompositePropagator,
  type BaggageEntry,
  TRACESTATE_MAX_MEMBERS,
  BAGGAGE_MAX_MEMBERS,
  BAGGAGE_MAX_BYTES,
  inject,
  extract,
  inject_context,
  extract_context,
  set_global_propagator,
  global_propagator,
  reset_global_propagator,
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
  parse_baggage_entries,
  format_baggage_entries,
  extract_baggage_entries,
  inject_baggage_entries,
}

///|
pub using @otlp {
  type OtlpHttpConfig,
  type OtlpHttpExporter,
  type Transport,
  type TransportResponse,
  OTLP_HTTP_PROTOBUF_PROTOCOL,
  OTLP_HTTP_JSON_PROTOCOL,
  is_supported_protocol,
  content_type_for_protocol,
  decode_export_response,
  decode_export_response_json,
  encode_trace_request,
  encode_trace_request_json,
}

// One-call setup: build a TracerProvider, optionally wire the exporters
// selected by `OTEL_TRACES_EXPORTER`, and install it as the process-wide
// provider.
//
// `endpoint` and `headers` override the values read from the
// OTEL_EXPORTER_OTLP_* environment variables. `resource` replaces the
// resource built from the environment, `resource_attributes` are merged into
// it, and `span_limits` replaces the limits read from the OTEL_SPAN_*
// environment variables.
//
// The exporters are selected by the `exporters` list when it is supplied and
// by the comma-separated `OTEL_TRACES_EXPORTER` environment variable
// otherwise: `otlp` (the default) installs the OTLP/HTTP exporter when a
// `transport` is supplied, `console` installs a `ConsoleSpanExporter` that
// prints every finished span, and `none` disables export. Spans are exported
// through a batch processor unless `use_batch` is false; `batch` overrides
// the queue size, export batch size and flush interval read from the
// OTEL_BSP_* environment variables. The console exporter always uses a simple
// processor.

///|
pub fn setup(
  service_name? : String,
  resource? : @sdk.Resource,
  resource_attributes? : Map[String, @sdk.AttributeValue],
  endpoint? : String,
  headers? : Map[String, String],
  sampler? : @sdk.Sampler,
  span_limits? : @sdk.SpanLimits,
  transport? : @otlp.Transport,
  exporters? : Array[String],
  use_batch? : Bool,
  batch? : @sdk.BatchConfig,
) -> @sdk.TracerProviderSdk {
  let mut provider = @sdk.TracerProviderSdk::new(service_name?)
  match resource {
    Some(value) => provider = provider.with_resource(value)
    None => ()
  }
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
  if @sdk.exporter_selected(exporters, "console") {
    let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(
      @sdk.ConsoleSpanExporter::new(),
    )
    provider = provider.with_span_processor(processor)
  }
  match transport {
    Some(send) =>
      if !@sdk.exporter_selected(exporters, "otlp") {
        // The OTLP exporter is not selected (for example `none` or
        // `console`), matching the native async `setup`.
        ()
      } else {
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
        let processor : &@sdk.SpanProcessor = match batch {
          // An explicit configuration always uses the batch processor.
          Some(config) => {
            let value : &@sdk.SpanProcessor = @sdk.BatchSpanProcessor::with_config(
              exporter, config,
            )
            value
          }
          None =>
            if use_batch.unwrap_or(true) {
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
        }
        provider = provider.with_span_processor(processor)
      }
    None => ()
  }
  @sdk.set_global_tracer_provider(provider)
  provider
}
