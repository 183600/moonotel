// OTLP/HTTP trace exporter.
//
// The exporter encodes spans as an `ExportTraceServiceRequest` protobuf body
// and POSTs it to `<endpoint>/v1/traces`. HTTP transport is injected, so the
// exporter works on any target and can be wired to `moonbitlang/async/http`,
// a test double, or any other client.

// Response returned by an injected transport.
pub(all) struct TransportResponse {
  status_code : Int
  body : Bytes
}

// HTTP transport: (url, headers, body) -> response.
pub type Transport = (String, Map[String, String], Bytes) -> TransportResponse

// Exporter configuration, following the OTEL_EXPORTER_OTLP_* environment
// variables. `endpoint` is a base URL; `traces_endpoint` (when present) is the
// full signal-specific URL set via OTEL_EXPORTER_OTLP_TRACES_ENDPOINT and is
// used verbatim.
pub(all) struct OtlpHttpConfig {
  endpoint : String
  traces_endpoint : String?
  headers : Map[String, String]
  timeout_millis : Int
  compression : String
  max_retries : Int
}

// Create a configuration with sensible defaults
// (endpoint `http://localhost:4318`, no compression, 10s timeout).
pub fn OtlpHttpConfig::new(
  endpoint? : String,
  headers? : Map[String, String],
  timeout_millis? : Int,
  compression? : String,
  max_retries? : Int
) -> OtlpHttpConfig {
  {
    endpoint: endpoint.unwrap_or("http://localhost:4318"),
    traces_endpoint: None,
    headers: headers.unwrap_or(Map::new()),
    timeout_millis: timeout_millis.unwrap_or(10000),
    compression: compression.unwrap_or("none"),
    max_retries: max_retries.unwrap_or(0),
  }
}

fn parse_headers(value : String) -> Map[String, String] {
  let headers = Map::new()
  for pair in value.split(",") {
    let text = pair.to_string()
    match text.split_once("=") {
      Some((key, header_value)) =>
        headers.set(
          key.to_string().trim().to_string(),
          header_value.to_string().trim().to_string(),
        )
      None => ()
    }
  }
  headers
}

// Build a configuration from the standard OTLP environment variables:
// OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_TRACES_ENDPOINT,
// OTEL_EXPORTER_OTLP_HEADERS, OTEL_EXPORTER_OTLP_COMPRESSION,
// OTEL_EXPORTER_OTLP_TIMEOUT (milliseconds).
pub fn OtlpHttpConfig::from_env() -> OtlpHttpConfig {
  let traces_endpoint = @env.get_env_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
  let generic_endpoint = @env.get_env_var("OTEL_EXPORTER_OTLP_ENDPOINT")
  let endpoint = match (generic_endpoint, traces_endpoint) {
    (Some(value), _) => value
    (None, Some(value)) => value
    (None, None) => "http://localhost:4318"
  }
  let headers = match @env.get_env_var("OTEL_EXPORTER_OTLP_HEADERS") {
    Some(value) => parse_headers(value)
    None => Map::new()
  }
  let compression = @env
    .get_env_var("OTEL_EXPORTER_OTLP_COMPRESSION")
    .unwrap_or("none")
  let timeout_millis = match @env.get_env_var("OTEL_EXPORTER_OTLP_TIMEOUT") {
    Some(value) => {
      let parsed = try @string.parse_int(value) catch {
        _ => 0
      }
      if parsed > 0 { parsed } else { 10000 }
    }
    None => 10000
  }
  {
    endpoint,
    traces_endpoint,
    headers,
    timeout_millis,
    compression,
    max_retries: 0,
  }
}

// Full URL of the trace export endpoint. The signal-specific
// `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` value is used verbatim; otherwise
// `/v1/traces` is appended to the base endpoint.
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

fn is_retryable_status(status_code : Int) -> Bool {
  match status_code {
    429 | 502 | 503 | 504 => true
    _ => false
  }
}

// An exporter that sends spans in OTLP/HTTP protobuf format.
pub struct OtlpHttpExporter {
  config : OtlpHttpConfig
  transport : Transport
}

// Create an exporter with an injected transport function.
pub fn OtlpHttpExporter::new(
  config : OtlpHttpConfig,
  transport : Transport
) -> OtlpHttpExporter {
  { config, transport }
}

// The exporter configuration.
pub fn OtlpHttpExporter::config(self : OtlpHttpExporter) -> OtlpHttpConfig {
  self.config
}

fn exporter_headers(config : OtlpHttpConfig) -> Map[String, String] {
  let headers = Map::new()
  config.headers.each(fn(key, value) { headers.set(key, value) })
  headers.set("content-type", "application/x-protobuf")
  headers
}

// Encode and POST the given spans. HTTP 200 (including partial success) is a
// success and is never retried; retryable status codes are retried up to
// `max_retries` times. The gzip compression setting is currently rejected at
// encode time.
pub fn OtlpHttpExporter::export_spans_http(
  self : OtlpHttpExporter,
  spans : Array[@sdk.SpanData]
) -> @sdk.ExportResult {
  if spans.length() == 0 {
    return @sdk.ExportSuccess
  }
  if self.config.compression != "none" {
    return @sdk.ExportFailure(
      "unsupported OTLP compression: " + self.config.compression,
    )
  }
  let body = encode_trace_request(spans)
  let url = self.config.traces_url()
  let headers = exporter_headers(self.config)
  let mut attempt = 0
  let mut last_failure = ""
  while attempt <= self.config.max_retries {
    let response = (self.transport)(url, headers, body)
    if response.status_code == 200 {
      return @sdk.ExportSuccess
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

pub impl @sdk.SpanExporter for OtlpHttpExporter with export_spans(self, spans) {
  self.export_spans_http(spans)
}

pub impl @sdk.SpanExporter for OtlpHttpExporter with shutdown(self) {
  let _ = self
}
