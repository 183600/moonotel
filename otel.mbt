// `183600/moonotel` is the main entry package. It re-exports the API, SDK,
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
  byte_to_hex_char,
  is_zero,
  TRACE_FLAGS_SAMPLED,
  TRACE_FLAGS_RANDOM,
}

///|
pub using @sdk {
  type AttributeValue,
  type SpanData,
  type SpanEvent,
  type SpanLink,
  type SamplingDecision,
  type SamplingParameters,
  sampling_decision_record_and_sample,
  sampling_decision_record_only,
  sampling_decision_drop,
  type ExportResult,
  type Sampler,
  type SpanLimits,
  type IdGenerator,
  type Resource,
  type ResourceAttributes,
  trait ResourceDetector,
  type SpanSdk,
  type Tracer,
  type TracerProviderSdk,
  type SimpleSpanProcessor,
  type BatchSpanProcessor,
  type MultiSpanProcessor,
  type BatchConfig,
  type InMemorySpanExporter,
  type ConsoleSpanExporter,
  trait SpanProcessor,
  trait SpanExporter,
  global_tracer,
  global_tracer_provider,
  no_op_tracer_provider,
  set_global_tracer_provider,
  shutdown_global_tracer_provider,
  force_flush_global_tracer_provider,
  traces_exporter_enabled,
  traces_exporter_disabled,
  exporter_selected,
  redact_sensitive_query_string,
  SDK_VERSION,
  TELEMETRY_SDK_NAME,
  TELEMETRY_SDK_LANGUAGE,
  TELEMETRY_SDK_VERSION,
  // Semantic-convention attribute keys.
  HTTP_REQUEST_METHOD,
  HTTP_RESPONSE_STATUS_CODE,
  HTTP_REQUEST_BODY_SIZE,
  HTTP_RESPONSE_BODY_SIZE,
  HTTP_ROUTE,
  HTTP_REQUEST_HEADER_PREFIX,
  HTTP_RESPONSE_HEADER_PREFIX,
  URL_FULL,
  URL_SCHEME,
  URL_PATH,
  URL_QUERY,
  SERVER_ADDRESS,
  SERVER_PORT,
  CLIENT_ADDRESS,
  CLIENT_PORT,
  USER_AGENT_ORIGINAL,
  NETWORK_PROTOCOL_NAME,
  NETWORK_PROTOCOL_VERSION,
  ERROR_TYPE,
  SERVICE_NAME,
  SERVICE_VERSION,
  DEPLOYMENT_ENVIRONMENT,
  EXCEPTION_TYPE,
  EXCEPTION_MESSAGE,
  EXCEPTION_STACKTRACE,
}

///|
pub using @context {
  type Context,
  type ContextStorage,
  current_context,
  current_span_context,
  attach,
  detach,
  with_context,
  with_span_context,
  set_context_storage,
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
  traceparent_header_name,
  tracestate_header_name,
  format_traceparent,
  parse_traceparent,
  parse_tracestate,
  extract_tracestate,
  inject_with_tracestate,
  baggage_header_name,
  context_baggage_header,
  inject_baggage,
  extract_baggage,
  extract_baggage_context,
  parse_baggage,
  format_baggage,
  percent_encode,
  percent_decode,
  percent_encoded_length,
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
  type RetryWait,
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
//
// The OTLP exporter needs a `transport` to send the payload. When the OTLP
// exporter is selected but no transport is supplied, the console exporter is
// installed instead so that finished spans are still exported (and visible)
// instead of being dropped silently. Selecting `none`, or an exporter that is
// not supported, still installs nothing.

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
  let console_selected = @sdk.exporter_selected(exporters, "console")
  let otlp_selected = @sdk.exporter_selected(exporters, "otlp")
  if console_selected {
    let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(
      @sdk.ConsoleSpanExporter::new(),
    )
    provider = provider.with_span_processor(processor)
  }
  match transport {
    Some(send) =>
      if !otlp_selected {
        // The OTLP exporter is not selected (for example `none` or
        // `console`), matching the native async `setup`.
        ()
      } else {
        let base = @otlp.OtlpHttpConfig::from_env()
        // Mirror `OtlpHttpConfig::new`: a blank programmatic endpoint is
        // treated as unset, so it neither replaces the environment endpoint
        // nor suppresses an environment traces endpoint.
        let endpoint_override = match endpoint {
          Some(value) => {
            let value = value.trim().to_owned()
            if value == "" {
              None
            } else {
              Some(value)
            }
          }
          None => None
        }
        let config : @otlp.OtlpHttpConfig = {
          ..base,
          endpoint: endpoint_override.unwrap_or(base.endpoint),
          traces_endpoint: match endpoint_override {
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
    None =>
      if otlp_selected && !console_selected {
        // The OTLP exporter is selected but there is no transport to send the
        // payload with, so fall back to the console exporter rather than
        // dropping every span silently.
        let processor : &@sdk.SpanProcessor = @sdk.SimpleSpanProcessor::new(
          @sdk.ConsoleSpanExporter::new(),
        )
        provider = provider.with_span_processor(processor)
      }
  }
  @sdk.set_global_tracer_provider(provider)
  provider
}
