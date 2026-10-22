// OTLP/HTTP trace exporter.
//
// The exporter encodes spans as an `ExportTraceServiceRequest` body — binary
// protobuf by default, or the JSON mapping when `protocol` is `http/json` —
// and POSTs it to `<endpoint>/v1/traces`. HTTP transport is injected, so the
// exporter works on any target and can be wired to `moonbitlang/async/http`,
// a test double, or any other client.

// Response returned by an injected transport. A non-positive status code
// reports a transport-level failure (no HTTP response was received), which is
// retried like the OTLP transient statuses.

///|
pub(all) struct TransportResponse {
  status_code : Int32
  body : Bytes
}

/// HTTP transport: `(url, headers, body) -> response`.
///
/// The transport runs synchronously inside `export_spans_http` (including its
/// retry loop) and the exporter cannot cancel it, so an injected transport is
/// expected to enforce its own timeout/deadline. `timeout_millis` from
/// `OtlpHttpConfig` is honored by the async exporter
/// (`183600/moonotel/exporter/otlp_async`), not by this synchronous path.
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

// Default `User-Agent` header value. The OTLP exporter specification asks
// protocol exporters to identify themselves, their language and their version
// (`OTel-OTLP-Exporter-<Language>/<Version>`).
// https://opentelemetry.io/docs/specs/otel/protocol/exporter/#user-agent

///|
fn default_user_agent() -> String {
  "OTel-OTLP-Exporter-MoonBit/" + @sdk.SDK_VERSION
}

// Number of retries used when `max_retries` is not set explicitly. OTLP
// requires transient errors (429/502/503/504 and transport failures) to be
// retried, so retries are enabled by default.

///|
const DEFAULT_MAX_RETRIES : Int32 = 3

// Default request timeout. Zero explicitly means "no timeout"; a negative
// programmatic value falls back to this default.

///|
const DEFAULT_TIMEOUT_MILLIS : Int32 = 10000

// Whether `protocol` is one of the OTLP/HTTP encodings supported by this
// exporter (`http/protobuf` and `http/json`). Other values (for example
// `grpc`) are rejected at export time.

///|
pub fn is_supported_protocol(protocol : String) -> Bool {
  let protocol = normalize_enum(protocol)
  protocol == OTLP_HTTP_PROTOBUF_PROTOCOL || protocol == OTLP_HTTP_JSON_PROTOCOL
}

// The `Content-Type` of an OTLP/HTTP request for `protocol`.

///|
pub fn content_type_for_protocol(protocol : String) -> String {
  if is_json_protocol(protocol) {
    "application/json"
  } else {
    "application/x-protobuf"
  }
}

// Enum-valued environment variables are matched case-insensitively. Values
// are trimmed so that values such as `" HTTP/JSON "` are accepted as well.

///|
fn normalize_enum(value : String) -> String {
  value.trim().to_owned().to_lower()
}

///|
fn is_json_protocol(protocol : String) -> Bool {
  normalize_enum(protocol) == OTLP_HTTP_JSON_PROTOCOL
}

// The protocol actually used for an export. A blank programmatic value falls
// back to the OTLP default (`http/protobuf`), matching `OtlpHttpConfig::new`
// and the environment-variable path even when the config was built directly.
fn effective_protocol(protocol : String) -> String {
  let normalized = normalize_enum(protocol)
  if normalized == "" {
    OTLP_HTTP_PROTOBUF_PROTOCOL
  } else {
    normalized
  }
}

// The compression actually used for an export. A blank programmatic value
// means `none`; any other unsupported value is rejected at export time.
fn effective_compression(compression : String) -> String {
  let normalized = normalize_enum(compression)
  if normalized == "" {
    "none"
  } else {
    normalized
  }
}

// The request timeout actually used for an export. A negative programmatic
// value falls back to the 10s default, matching `OtlpHttpConfig::new`; zero
// explicitly disables the timeout. This matters for a config built directly
// from the public fields, which has not passed through the constructor.
pub fn OtlpHttpConfig::effective_timeout_millis(
  self : OtlpHttpConfig,
) -> Int32 {
  if self.timeout_millis < 0 {
    DEFAULT_TIMEOUT_MILLIS
  } else {
    self.timeout_millis
  }
}

// Create a configuration with sensible defaults
// (endpoint `http://localhost:4318`, no compression, `http/protobuf`, 10s
// timeout, 3 retries for retryable statuses). When `traces_endpoint` is given
// it is the full trace URL and is used verbatim, taking precedence over
// `endpoint`.
//
// Invalid boundary values fall back to those defaults: a negative timeout is
// invalid (0 explicitly means "no timeout"), a negative retry count means no
// retries, and blank endpoint or enum values are treated as unset, matching the
// environment-variable path.

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
  let retries = max_retries.unwrap_or(DEFAULT_MAX_RETRIES)
  let timeout = timeout_millis.unwrap_or(DEFAULT_TIMEOUT_MILLIS)
  let compression = normalize_enum(compression.unwrap_or("none"))
  let protocol = normalize_enum(protocol.unwrap_or(OTLP_HTTP_PROTOBUF_PROTOCOL))
  let endpoint = match endpoint {
    Some(value) => {
      let value = value.trim().to_owned()
      if value == "" {
        "http://localhost:4318"
      } else {
        value
      }
    }
    None => "http://localhost:4318"
  }
  let traces_endpoint = match traces_endpoint {
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
  {
    endpoint,
    traces_endpoint,
    // The config owns a snapshot of the headers: mutating the caller's map
    // afterwards cannot change what an exporter built from this config sends.
    headers: match headers {
      Some(values) => values.copy()
      None => Map([])
    },
    timeout_millis: if timeout < 0 {
      DEFAULT_TIMEOUT_MILLIS
    } else {
      timeout
    },
    compression: if compression == "" {
      "none"
    } else {
      compression
    },
    protocol: if protocol == "" {
      OTLP_HTTP_PROTOBUF_PROTOCOL
    } else {
      protocol
    },
    max_retries: if retries < 0 {
      0
    } else {
      retries
    },
  }
}

// Merge `headers` into this configuration's headers, returning a new config.
// HTTP header names are case-insensitive, so an override replaces any existing
// header with the same spelling regardless of casing. The original config is
// unchanged, which lets `setup` layer programmatic headers over the values
// read from the `OTEL_EXPORTER_OTLP_*_HEADERS` environment variables.

///|
pub fn OtlpHttpConfig::with_headers(
  self : OtlpHttpConfig,
  headers : Map[String, String],
) -> OtlpHttpConfig {
  let merged = self.headers.copy()
  for key, value in headers {
    set_header(merged, key, value)
  }
  { ..self, headers: merged, }
}

///|
// Reverse table: the 0-15 value of each ASCII hex digit, -1 for every other
// code unit below 128.
let hex_value : FixedArray[Int32] = build_hex_value()

///|
fn build_hex_value() -> FixedArray[Int32] {
  let table : FixedArray[Int32] = FixedArray::make(128, -1)
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

///|
fn hex_digit_value(c : Char) -> Int32 {
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

///|
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
      for byte in encode_utf8_lossy(value.view(start_offset=run_start, end_offset=j)) {
        bytes.push(byte)
      }
      i = j
    }
  }
  @utf8.decode_lossy(Bytes::from_array(bytes).exact_view())
}

// Store a header, replacing any existing header whose name differs only by
// case. HTTP header names are case-insensitive, so `X-Token` and `x-token`
// must not be sent as two distinct headers.

///|
fn set_header(
  headers : Map[String, String],
  key : String,
  value : String,
) -> Unit {
  let normalized = key.to_lower()
  let stale : Array[String] = []
  for existing, _ in headers {
    if existing.to_lower() == normalized {
      stale.push(existing)
    }
  }
  for existing in stale {
    headers.remove(existing)
  }
  headers.set(key, value)
}

///|
fn parse_headers(value : String) -> Map[String, String] {
  let headers = Map([])
  for pair in value.split(",") {
    match pair.trim().split_once("=") {
      Some((key, header_value)) => {
        let trimmed_key = key.trim()
        if trimmed_key != "" {
          set_header(
            headers,
            trimmed_key.to_owned(),
            decode_header_value(header_value.trim()),
          )
        }
      }
      None => ()
    }
  }
  headers
}

// The value of the environment variable `name` when it is set and not blank,
// `None` otherwise (an empty value is treated as unset, as OTLP requires).

///|
fn non_blank_env_value(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) =>
      if value.trim() != "" {
        Some(value.trim().to_owned())
      } else {
        None
      }
    None => None
  }
}

// Parse the timeout environment variable `name`. `None` when the variable is
// unset, blank, negative or not an integer, so that the caller can continue
// with the next fallback. A zero timeout means "no timeout" per the
// OpenTelemetry configuration specification.

///|
fn parse_timeout_decimal(value : StringView) -> Int32? {
  let len = value.length()
  if len == 0 {
    return None
  }
  let mut number = 0
  let mut i = 0
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code < 0x30 || code > 0x39 {
      return None
    }
    let digit = code - 0x30
    if number > (2147483647 - digit) / 10 {
      return None
    }
    number = number * 10 + digit
    i = i + 1
  }
  Some(number)
}

///|
fn parse_timeout_env(name : String) -> Int32? {
  match @env.get_env_var(name) {
    Some(value) => parse_timeout_decimal(value.trim())
    None => None
  }
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
  let traces_endpoint = non_blank_env_value("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
  let generic_endpoint = non_blank_env_value("OTEL_EXPORTER_OTLP_ENDPOINT")
  let endpoint = match generic_endpoint {
    Some(value) => value
    None => "http://localhost:4318"
  }
  let headers = match non_blank_env_value("OTEL_EXPORTER_OTLP_HEADERS") {
    Some(value) => parse_headers(value)
    None => Map([])
  }
  match non_blank_env_value("OTEL_EXPORTER_OTLP_TRACES_HEADERS") {
    Some(value) => {
      let specific = parse_headers(value)
      for key, header_value in specific {
        // Signal-specific headers override generic headers even when the
        // two spellings differ only by case.
        set_header(headers, key, header_value)
      }
    }
    None => ()
  }
  let compression = match
    non_blank_env_value("OTEL_EXPORTER_OTLP_TRACES_COMPRESSION") {
    Some(value) => value
    None =>
      match non_blank_env_value("OTEL_EXPORTER_OTLP_COMPRESSION") {
        Some(value) => value
        None => "none"
      }
  }
  let protocol = match
    non_blank_env_value("OTEL_EXPORTER_OTLP_TRACES_PROTOCOL") {
    Some(value) => value
    None =>
      match non_blank_env_value("OTEL_EXPORTER_OTLP_PROTOCOL") {
        Some(value) => value
        None => OTLP_HTTP_PROTOBUF_PROTOCOL
      }
  }
  let timeout_millis = match
    parse_timeout_env("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT") {
    Some(value) => value
    None =>
      match parse_timeout_env("OTEL_EXPORTER_OTLP_TIMEOUT") {
        Some(value) => value
        None => DEFAULT_TIMEOUT_MILLIS
      }
  }
  {
    endpoint,
    traces_endpoint,
    headers,
    timeout_millis,
    compression: normalize_enum(compression),
    protocol: normalize_enum(protocol),
    max_retries: DEFAULT_MAX_RETRIES,
  }
}

// Full URL of the trace export endpoint. The signal-specific
// `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` value is used verbatim, except that a
// URL without a path part is sent to the root path `/` as required by the
// OTLP/HTTP specification; otherwise `/v1/traces` is appended to the base
// endpoint.
//
// Per the OTLP specification `OTEL_EXPORTER_OTLP_ENDPOINT` is a base URL, not
// a signal URL. Users still sometimes pass the full `.../v1/traces` URL; in
// that case we do not append the path a second time. This keeps both forms
// working instead of silently POSTing to `.../v1/traces/v1/traces`.

///|
fn path_and_suffix(endpoint : String) -> (String, String) {
  let mut cut = endpoint.length()
  match endpoint.find("?") {
    Some(index) => cut = index
    None => ()
  }
  match endpoint.find("#") {
    Some(index) => if index < cut { cut = index }
    None => ()
  }
  (endpoint[:cut].to_owned(), endpoint[cut:].to_owned())
}

// Add the root path to an absolute URL whose authority has no path part. The
// OTLP/HTTP specification requires per-signal endpoints without a path to be
// sent to `/`; the query and fragment components are preserved.
fn with_root_path(url : String) -> String {
  let (path, suffix) = path_and_suffix(url)
  match path.find("://") {
    Some(scheme_end) => {
      let after_scheme = path[scheme_end + 3:]
      if after_scheme.find("/") is None {
        path + "/" + suffix
      } else {
        url
      }
    }
    None => url
  }
}

///|
pub fn OtlpHttpConfig::traces_url(self : OtlpHttpConfig) -> String {
  // A config built directly (rather than with `new` / `from_env`) may carry
  // untrimmed or blank strings. Treat surrounding whitespace as insignificant
  // and blank values like unset, so a direct config behaves like the same
  // values passed through the constructor.
  let traces_endpoint = match self.traces_endpoint {
    Some(full_url) => {
      let trimmed = full_url.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
  match traces_endpoint {
    Some(full_url) => with_root_path(full_url)
    None => {
      let endpoint = self.endpoint.trim().to_owned()
      let endpoint = if endpoint == "" {
        "http://localhost:4318"
      } else {
        endpoint
      }
      let (path, suffix) = path_and_suffix(endpoint)
      if path.has_suffix("/v1/traces") || path.has_suffix("/v1/traces/") {
        endpoint
      } else if path.has_suffix("/") {
        path[:path.length() - 1].to_owned() + "/v1/traces" + suffix
      } else {
        path + "/v1/traces" + suffix
      }
    }
  }
}

///|
fn is_retryable_status(status_code : Int32) -> Bool {
  match status_code {
    429 | 502 | 503 | 504 => true
    // The synchronous transport has no error channel, so a non-positive
    // status reports that the request could not reach the server.
    _ => status_code <= 0
  }
}

// Wait strategy invoked before retry attempt `attempt` (1-based). The
// synchronous exporter has no scheduler to yield to, so the default performs
// no wait. Callers that run inside an event loop can inject a cooperative
// wait (for example `@async.sleep`).

///|
pub type RetryWait = (Int32) -> Unit

// An exporter that sends spans in OTLP/HTTP protobuf format.

///|
pub struct OtlpHttpExporter {
  config : OtlpHttpConfig
  transport : Transport
  // The trace endpoint URL derived from the config strings.
  url : String
  // Request headers (configured headers plus `content-type`).
  headers : Map[String, String]
  retry_wait : RetryWait
  mut shutdown_called : Bool
}

// Create an exporter with an injected transport function and an optional wait
// strategy used between retries.

///|
pub fn OtlpHttpExporter::new(
  config : OtlpHttpConfig,
  transport : Transport,
  retry_wait? : RetryWait,
) -> OtlpHttpExporter {
  // Snapshot the header map so that mutating the caller's config (or a map it
  // shares with the config) after construction cannot change the exporter's
  // configuration or the headers of a later export.
  let config = { ..config, headers: config.headers.copy() }
  {
    config,
    transport,
    url: config.traces_url(),
    headers: exporter_headers(config),
    retry_wait: retry_wait.unwrap_or(fn(_attempt) { () }),
    shutdown_called: false,
  }
}

// The exporter configuration, as an isolated copy: mutating the returned
// header map cannot change the exporter or the headers of a later export.

///|
pub fn OtlpHttpExporter::config(self : OtlpHttpExporter) -> OtlpHttpConfig {
  { ..self.config, headers: self.config.headers.copy() }
}

// Whether `shutdown` has been called. A shut-down exporter rejects further
// export attempts, as required by the OpenTelemetry exporter specification.

///|
pub fn OtlpHttpExporter::is_shutdown(self : OtlpHttpExporter) -> Bool {
  self.shutdown_called
}

///|
fn map_capacity_for_entries(entries : Int) -> Int {
  let capacity = entries.next_power_of_two()
  if entries > capacity * 13 / 16 {
    capacity * 2
  } else {
    capacity
  }
}

///|
fn exporter_headers(config : OtlpHttpConfig) -> Map[String, String] {
  let headers = Map(
    [], capacity=map_capacity_for_entries(config.headers.length() + 3),
  )
  // Install the default `User-Agent` first: an explicitly configured one is
  // copied below and replaces it case-insensitively.
  set_header(headers, "user-agent", default_user_agent())
  for key, value in config.headers {
    // HTTP header names are case-insensitive, so drop any user-configured
    // `Content-Type`, `Accept` or `Content-Encoding` spelling before adding
    // the protocol's own values, and collapse differently-cased duplicates of
    // other headers. This exporter never compresses request bodies, so a
    // configured `Content-Encoding` would describe the body incorrectly.
    let lower = key.to_lower()
    if lower != "content-type" &&
      lower != "accept" &&
      lower != "content-encoding" {
      set_header(headers, key, value)
    }
  }
  let content_type = content_type_for_protocol(config.protocol)
  headers.set("content-type", content_type)
  // The OTLP/HTTP specification asks the client to announce the response
  // format it accepts; the collector answers with the same format.
  headers.set("accept", content_type)
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
  if self.shutdown_called {
    return @sdk.ExportFailure("OTLP exporter is shut down")
  }
  if spans.length() == 0 {
    return @sdk.ExportSuccess
  }
  let protocol = effective_protocol(self.config.protocol)
  if !is_supported_protocol(protocol) {
    return @sdk.ExportFailure(
      "unsupported OTLP protocol: " + self.config.protocol,
    )
  }
  let compression = effective_compression(self.config.compression)
  if compression != "none" {
    return @sdk.ExportFailure(
      "unsupported OTLP compression: " + self.config.compression,
    )
  }
  let json = is_json_protocol(protocol)
  let body = if json {
    encode_trace_request_json(spans)
  } else {
    encode_trace_request(spans)
  }
  // Every span in the batch was skipped because its live IDs were malformed.
  // There is nothing to send, so do not issue an empty ExportTraceServiceRequest.
  if body.length() == 0 {
    return @sdk.ExportSuccess
  }
  let url = self.url
  let headers = self.headers
  let max_retries = if self.config.max_retries < 0 {
    0
  } else {
    self.config.max_retries
  }
  let mut attempt = 0
  let mut last_failure = ""
  while attempt <= max_retries {
    // The transport or retry wait may have shut the exporter down reentrantly;
    // a shut-down exporter must not send further attempts.
    if self.shutdown_called {
      return @sdk.ExportFailure("OTLP exporter is shut down")
    }
    if attempt > 0 {
      (self.retry_wait)(attempt)
      // The wait strategy may shut the exporter down reentrantly; do not send
      // another attempt after that.
      if self.shutdown_called {
        return @sdk.ExportFailure("OTLP exporter is shut down")
      }
    }
    // The transport receives its own copy: a client wrapper may normalize or
    // add headers, and that must not mutate the exporter's reusable snapshot
    // or the headers of later attempts.
    let response = (self.transport)(url, headers.copy(), body)
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

// Shut the exporter down. Idempotent; after this call `export_spans_http`
// returns an export failure without invoking the transport.

///|
pub impl @sdk.SpanExporter for OtlpHttpExporter with fn shutdown(self) {
  self.shutdown_called = true
}

///|
pub extend OtlpHttpExporter with @sdk.SpanExporter::{export_spans, export_span, shutdown}
