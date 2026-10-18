// OTLP/HTTP trace exporter.
//
// The exporter encodes spans as an `ExportTraceServiceRequest` body — binary
// protobuf by default, or the JSON mapping when `protocol` is `http/json` —
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

// The default OTLP/HTTP protocol: binary protobuf.

///|
pub const OTLP_HTTP_PROTOBUF_PROTOCOL : String = "http/protobuf"

// The JSON OTLP/HTTP protocol.

///|
pub const OTLP_HTTP_JSON_PROTOCOL : String = "http/json"

// Whether `protocol` is one of the OTLP/HTTP encodings supported by this
// exporter (`http/protobuf` and `http/json`). Other values (for example
// `grpc`) are rejected at export time.

///|
pub fn is_supported_protocol(protocol : String) -> Bool {
  protocol == OTLP_HTTP_PROTOBUF_PROTOCOL || protocol == OTLP_HTTP_JSON_PROTOCOL
}

// The `Content-Type` of an OTLP/HTTP request for `protocol`.

///|
pub fn content_type_for_protocol(protocol : String) -> String {
  if protocol == OTLP_HTTP_JSON_PROTOCOL {
    "application/json"
  } else {
    "application/x-protobuf"
  }
}

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
// Reverse table: the 0-15 value of each ASCII hex digit, -1 for every other
// code unit below 128.
let hex_value : FixedArray[Int] = build_hex_value()

fn build_hex_value() -> FixedArray[Int] {
  let table : FixedArray[Int] = FixedArray::make(128, -1)
  let mut i = 0
  while i < 10 {
    table.unsafe_set(48 + i, i)
    i = i + 1
  }
  let mut j = 0
  while j < 6 {
    table.unsafe_set(65 + j, 10 + j)
    table.unsafe_set(97 + j, 10 + j)
    j = j + 1
  }
  table
}

fn hex_digit_value(c : Char) -> Int {
  let code = c.to_int()
  if code >= 0 && code < 128 {
    hex_value.unsafe_get(code)
  } else {
    -1
  }
}

// Decode the `%XX` sequences used by `OTEL_EXPORTER_OTLP_HEADERS` values.
// The header format follows W3C Baggage, where values are percent-encoded.
// Invalid sequences are kept verbatim; keys are not decoded.
fn decode_header_value(value : StringView) -> String {
  if value.find("%") is None {
    return value.to_owned()
  }
  let len = value.length()
  let bytes : Array[Byte] = Array(capacity=len)
  let mut i = 0
  while i < len {
    let c = value.unsafe_get(i).unsafe_to_char()
    if c == '%' && i + 2 < len {
      let hi = hex_digit_value(value.unsafe_get(i + 1).unsafe_to_char())
      let lo = hex_digit_value(value.unsafe_get(i + 2).unsafe_to_char())
      if hi >= 0 && lo >= 0 {
        bytes.push((hi * 16 + lo).to_byte())
        i = i + 3
        continue
      }
    }
    let code = c.to_int()
    if code < 0x80 {
      // ASCII characters encode to a single UTF-8 byte.
      bytes.push(code.to_byte())
      i = i + 1
    } else {
      // Encode a whole run of non-ASCII code units together so that surrogate
      // pairs are encoded as one character.
      let run_start = i
      let mut j = i
      while j < len {
        if value.unsafe_get(j).to_int() < 0x80 {
          break
        }
        j = j + 1
      }
      for byte in @utf8.encode(value.view(start_offset=run_start, end_offset=j)) {
        bytes.push(byte)
      }
      i = j
    }
  }
  @utf8.decode_lossy(Bytes::from_array(bytes).exact_view())
}

///|
fn parse_headers(value : String) -> Map[String, String] {
  let headers = Map([])
  for pair in value.split(",") {
    match pair.trim().split_once("=") {
      Some((key, header_value)) =>
        headers.set(
          key.trim().to_owned(),
          decode_header_value(header_value.trim()),
        )
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
  // An empty (or blank) environment variable is treated as unset.
  let traces_endpoint = match
    @env.get_env_var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT") {
    Some(value) => if value.trim() != "" { Some(value) } else { None }
    None => None
  }
  let generic_endpoint = match @env.get_env_var("OTEL_EXPORTER_OTLP_ENDPOINT") {
    Some(value) => if value.trim() != "" { Some(value) } else { None }
    None => None
  }
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
      specific.each(fn(key, header_value) { headers.set(key, header_value) })
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
  let parsed = @string.parse_int(value.trim()) catch { _ => 0 }
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
  let headers = Map(
    [],
    capacity=(config.headers.length() + 1) * 2,
  )
  config.headers.each(fn(key, value) { headers.set(key, value) })
  headers.set("content-type", content_type_for_protocol(config.protocol))
  headers
}

// Encode and POST the given spans. HTTP 200 (including partial success) is a
// success and is never retried; the response body is decoded so that a
// `partial_success` is surfaced as an export failure. Retryable status codes
// are retried up to `max_retries` times. Unsupported protocols and the gzip
// compression setting are rejected at encode time; `http/json` bodies are
// encoded with the OTLP JSON mapping.

///|
pub fn OtlpHttpExporter::export_spans_http(
  self : OtlpHttpExporter,
  spans : Array[@sdk.SpanData],
) -> @sdk.ExportResult {
  if spans.length() == 0 {
    return @sdk.ExportSuccess
  }
  if !is_supported_protocol(self.config.protocol) {
    return @sdk.ExportFailure(
      "unsupported OTLP protocol: " + self.config.protocol,
    )
  }
  if self.config.compression != "none" {
    return @sdk.ExportFailure(
      "unsupported OTLP compression: " + self.config.compression,
    )
  }
  let json = self.config.protocol == OTLP_HTTP_JSON_PROTOCOL
  let body = if json {
    encode_trace_request_json(spans)
  } else {
    encode_trace_request(spans)
  }
  let url = self.url
  let headers = exporter_headers(self.config)
  let mut attempt = 0
  let mut last_failure = ""
  while attempt <= self.config.max_retries {
    let response = (self.transport)(url, headers, body)
    if response.status_code == 200 {
      if json {
        return decode_export_response_json(response.body)
      } else {
        return decode_export_response(response.body)
      }
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
