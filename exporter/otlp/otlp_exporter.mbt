// OTLP/HTTP trace exporter.
//
// The exporter encodes spans as an `ExportTraceServiceRequest` protobuf body
// and POSTs it to `<endpoint>/v1/traces`. HTTP transport is injected, so the
// exporter works on any target and can be wired to `moonbitlang/async/http`,
// a test double, or any other client.

// Response returned by an injected transport.
///|
pub(all) struct TransportResponse {
  status_code : Int32
  body : Bytes
}

// HTTP transport: (url, headers, body) -> response.

///|
pub type Transport = (String, Map[String, String], Bytes) -> TransportResponse

// Exporter configuration, following the OTEL_EXPORTER_OTLP_* environment
// variables. `endpoint` is a base URL; `traces_endpoint` (when present) is the
// full signal-specific URL set via OTEL_EXPORTER_OTLP_TRACES_ENDPOINT and is
// used verbatim.

///|
pub(all) struct OtlpHttpConfig {
  endpoint : String
  traces_endpoint : String?
  headers : Map[String, String]
  timeout_millis : Int32
  compression : String
  protocol : String
  max_retries : Int32
}

// The only protocol supported by this exporter.

///|
pub const OTLP_HTTP_PROTOBUF_PROTOCOL : String = "http/protobuf"

// Create a configuration with sensible defaults
// (endpoint `http://localhost:4318`, no compression, `http/protobuf`, 10s
// timeout). When `traces_endpoint` is given it is the full trace URL and is
// used verbatim, taking precedence over `endpoint`.

///|
pub fn OtlpHttpConfig::new(
  endpoint? : String,
  traces_endpoint? : String,
  headers? : Map[String, String],
  timeout_millis? : Int32,
  compression? : String,
  protocol? : String,
  max_retries? : Int32,
) -> OtlpHttpConfig {
  {
    endpoint: endpoint.unwrap_or("http://localhost:4318"),
    traces_endpoint,
    headers: headers.unwrap_or(Map([])),
    timeout_millis: timeout_millis.unwrap_or(10000),
    compression: compression.unwrap_or("none"),
    protocol: protocol.unwrap_or(OTLP_HTTP_PROTOBUF_PROTOCOL),
    max_retries: max_retries.unwrap_or(0),
  }
}

///|
fn parse_headers(value : String) -> Map[String, String] {
  let headers = Map([])
  for pair in value.split(",") {
    match pair.trim().split_once("=") {
      Some((key, header_value)) =>
        headers.set(key.trim().to_owned(), header_value.trim().to_owned())
      None => ()
    }
  }
  headers
}

// Build a configuration from the standard OTLP environment variables:
// OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_TRACES_ENDPOINT,
// OTEL_EXPORTER_OTLP_HEADERS, OTEL_EXPORTER_OTLP_TRACES_HEADERS,
// OTEL_EXPORTER_OTLP_COMPRESSION, OTEL_EXPORTER_OTLP_TRACES_COMPRESSION,
// OTEL_EXPORTER_OTLP_PROTOCOL, OTEL_EXPORTER_OTLP_TRACES_PROTOCOL,
// OTEL_EXPORTER_OTLP_TIMEOUT and OTEL_EXPORTER_OTLP_TRACES_TIMEOUT
// (timeouts in milliseconds). Signal-specific variables take precedence over
// their generic counterparts.

///|
pub fn OtlpHttpConfig::from_env() -> OtlpHttpConfig {
  let traces_endpoint = @env.get_env_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
  let generic_endpoint = @env.get_env_var("OTEL_EXPORTER_OTLP_ENDPOINT")
  let endpoint = match generic_endpoint {
    Some(value) => value
    None =>
      match traces_endpoint {
        Some(value) => value
        None => "http://localhost:4318"
      }
  }
  let headers = match @env.get_env_var("OTEL_EXPORTER_OTLP_HEADERS") {
    Some(value) => parse_headers(value)
    None => Map([])
  }
  match @env.get_env_var("OTEL_EXPORTER_OTLP_TRACES_HEADERS") {
    Some(value) => {
      let specific = parse_headers(value)
      for entry in specific.iter() {
        let (key, header_value) = entry
        headers.set(key, header_value)
      }
    }
    None => ()
  }
  let specific_compression = match
    @env.get_env_var("OTEL_EXPORTER_OTLP_TRACES_COMPRESSION") {
    Some(value) => value.trim().to_owned()
    None => ""
  }
  let compression = if specific_compression != "" {
    specific_compression
  } else {
    match @env.get_env_var("OTEL_EXPORTER_OTLP_COMPRESSION") {
      Some(value) =>
        if value.trim() != "" {
          value.trim().to_owned()
        } else {
          "none"
        }
      None => "none"
    }
  }
  let protocol = match @env.get_env_var("OTEL_EXPORTER_OTLP_TRACES_PROTOCOL") {
    Some(value) =>
      if value.trim() != "" {
        value.trim().to_owned()
      } else {
        OTLP_HTTP_PROTOBUF_PROTOCOL
      }
    None =>
      match @env.get_env_var("OTEL_EXPORTER_OTLP_PROTOCOL") {
        Some(value) =>
          if value.trim() != "" {
            value.trim().to_owned()
          } else {
            OTLP_HTTP_PROTOBUF_PROTOCOL
          }
        None => OTLP_HTTP_PROTOBUF_PROTOCOL
      }
  }
  let timeout_millis = match
    @env.get_env_var("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT") {
    Some(value) => parse_timeout(value)
    None =>
      match @env.get_env_var("OTEL_EXPORTER_OTLP_TIMEOUT") {
        Some(value) => parse_timeout(value)
        None => 10000
      }
  }
  {
    endpoint,
    traces_endpoint,
    headers,
    timeout_millis,
    compression,
    protocol,
    max_retries: 0,
  }
}

///|
fn parse_timeout(value : String) -> Int32 {
  let parsed = @string.parse_int(value) catch { _ => 0 }
  if parsed > 0 {
    parsed
  } else {
    10000
  }
}

// Full URL of the trace export endpoint. The signal-specific
// `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` value is used verbatim; otherwise
// `/v1/traces` is appended to the base endpoint.

///|
pub fn OtlpHttpConfig::traces_url(self : OtlpHttpConfig) -> String {
  match self.traces_endpoint {
    Some(full_url) => full_url
    None =>
      if self.endpoint.has_suffix("/") {
        self.endpoint + "v1/traces"
      } else {
        self.endpoint + "/v1/traces"
      }
  }
}

///|
fn is_retryable_status(status_code : Int32) -> Bool {
  match status_code {
    429 | 502 | 503 | 504 => true
    _ => false
  }
}

// An exporter that sends spans in OTLP/HTTP protobuf format.

///|
pub struct OtlpHttpExporter {
  config : OtlpHttpConfig
  transport : Transport
  // The trace endpoint URL derived from the config strings.
  url : String
}

// Create an exporter with an injected transport function.

///|
pub fn OtlpHttpExporter::new(
  config : OtlpHttpConfig,
  transport : Transport,
) -> OtlpHttpExporter {
  { config, transport, url: config.traces_url(), }
}

// The exporter configuration.

///|
pub fn OtlpHttpExporter::config(self : OtlpHttpExporter) -> OtlpHttpConfig {
  self.config
}

///|
fn exporter_headers(config : OtlpHttpConfig) -> Map[String, String] {
  let headers = Map([])
  for entry in config.headers.iter() {
    let (key, value) = entry
    headers.set(key, value)
  }
  headers.set("content-type", "application/x-protobuf")
  headers
}

// Encode and POST the given spans. HTTP 200 (including partial success) is a
// success and is never retried; the response body is decoded so that a
// `partial_success` is surfaced as an export failure. Retryable status codes
// are retried up to `max_retries` times. Unsupported protocols and the gzip
// compression setting are rejected at encode time.

///|
pub fn OtlpHttpExporter::export_spans_http(
  self : OtlpHttpExporter,
  spans : Array[@sdk.SpanData],
) -> @sdk.ExportResult {
  if spans.length() == 0 {
    return @sdk.ExportSuccess
  }
  if self.config.protocol != OTLP_HTTP_PROTOBUF_PROTOCOL {
    return @sdk.ExportFailure(
      "unsupported OTLP protocol: " + self.config.protocol,
    )
  }
  if self.config.compression != "none" {
    return @sdk.ExportFailure(
      "unsupported OTLP compression: " + self.config.compression,
    )
  }
  let body = encode_trace_request(spans)
  let url = self.url
  let headers = exporter_headers(self.config)
  let mut attempt = 0
  let mut last_failure = ""
  while attempt <= self.config.max_retries {
    let response = (self.transport)(url, headers, body)
    if response.status_code == 200 {
      return decode_export_response(response.body)
    }
    last_failure = "OTLP export failed with HTTP status " +
      response.status_code.to_string()
    if !is_retryable_status(response.status_code) {
      return @sdk.ExportFailure(last_failure)
    }
    attempt = attempt + 1
  }
  @sdk.ExportFailure(last_failure)
}

///|
pub impl @sdk.SpanExporter for OtlpHttpExporter with fn export_spans(
  self,
  spans,
) {
  self.export_spans_http(spans)
}

///|
pub impl @sdk.SpanExporter for OtlpHttpExporter with fn shutdown(self) {
  let _ = self
}

///|
pub extend OtlpHttpExporter with @sdk.SpanExporter::{export_spans, shutdown}
