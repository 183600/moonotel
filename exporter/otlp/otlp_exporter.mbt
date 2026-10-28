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

// Whether a code unit is an HTTP token character (RFC 9110 `tchar`). Header
// names must be non-empty tokens; names containing whitespace, `:`, control
// characters or non-ASCII text cannot be sent as HTTP fields.

///|
fn is_http_token_code(code : Int32) -> Bool {
  (code >= 0x30 && code <= 0x39) ||
  (code >= 0x41 && code <= 0x5A) ||
  (code >= 0x61 && code <= 0x7A) ||
  code == 0x21 ||
  (code >= 0x23 && code <= 0x27) ||
  code == 0x2A ||
  code == 0x2B ||
  code == 0x2D ||
  code == 0x2E ||
  code == 0x5E ||
  code == 0x5F ||
  code == 0x60 ||
  code == 0x7C ||
  code == 0x7E
}

// Whether `name` is a valid HTTP header name (a non-empty RFC 9110 token).

///|
pub fn is_valid_http_header_name(name : StringView) -> Bool {
  let len = name.length()
  if len == 0 {
    return false
  }
  let mut i = 0
  while i < len {
    if !is_http_token_code(name.unsafe_get(i).to_int()) {
      return false
    }
    i = i + 1
  }
  true
}

// Whether `value` can be sent as an HTTP field value. HTTP forbids CR, LF and
// NUL because they delimit fields, and every other control character except
// HTAB is not a field-vchar. Non-ASCII text is allowed (obs-text).

// Whether `value` is well-formed UTF-16. A configured header is forwarded to
// a UTF-8 transport, and an unpaired surrogate cannot be encoded; dropping the
// header is better than aborting the export. Complete surrogate pairs are
// valid non-ASCII field text.

///|
fn has_valid_utf16(value : String) -> Bool {
  let len = value.length()
  let mut i = 0
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code >= 0xD800 && code <= 0xDBFF {
      if i + 1 >= len {
        return false
      }
      let low = value.unsafe_get(i + 1).to_int()
      if low < 0xDC00 || low > 0xDFFF {
        return false
      }
      i = i + 2
    } else if code >= 0xDC00 && code <= 0xDFFF {
      return false
    } else {
      i = i + 1
    }
  }
  true
}

///|
pub fn is_valid_http_header_value(value : String) -> Bool {
  let len = value.length()
  let mut i = 0
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code == 0x00 || code == 0x0A || code == 0x0D || code == 0x7F {
      return false
    }
    if code < 0x20 && code != 0x09 {
      return false
    }
    i = i + 1
  }
  has_valid_utf16(value)
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
    // Only headers that can be represented as HTTP fields are kept.
    headers: match headers {
      Some(values) => {
        let snapshot = Map([], capacity=values.length())
        for key, value in values {
          if is_valid_http_header_name(key) && is_valid_http_header_value(value) {
            set_header(snapshot, key, value)
          }
        }
        snapshot
      }
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
    if is_valid_http_header_name(key) && is_valid_http_header_value(value) {
      set_header(merged, key, value)
    }
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
        let trimmed_value = header_value.trim()
        // Validate the raw value before decoding: lossy decoding must not turn
        // an unpaired surrogate into a valid replacement character.
        let raw_value_is_valid = is_valid_http_header_value(
          trimmed_value.to_owned(),
        )
        let value = decode_header_value(trimmed_value)
        // Malformed names and values are not representable as HTTP fields
        // (and a CR/LF in a value would split the request into extra fields),
        // so drop the pair instead of forwarding it to the transport.
        if raw_value_is_valid && is_valid_http_header_name(trimmed_key) &&
          is_valid_http_header_value(value) {
          set_header(headers, trimmed_key.to_owned(), value)
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
  // A network-path reference (`//host:4318`) also has an authority but no
  // path. Add the root path for it, just like an absolute URL.
  if path.has_prefix("//") {
    let after_authority = path[2:]
    if after_authority.find("/") is None {
      path + "/" + suffix
    } else {
      url
    }
  } else {
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
}

// Whether `c` may start a URI scheme (`ALPHA`).

///|
fn is_scheme_start_char(code : Int32) -> Bool {
  (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)
}

// Whether `c` may continue a URI scheme (`ALPHA / DIGIT / "+" / "-" / "."`).

///|
fn is_scheme_char(code : Int32) -> Bool {
  is_scheme_start_char(code) ||
  (code >= 0x30 && code <= 0x39) ||
  code == 0x2B ||
  code == 0x2D ||
  code == 0x2E
}

// Index of the `:` in a valid `scheme://` prefix, or `None` when the URL does
// not start with an absolute URI scheme.

///|
fn scheme_colon_index(url : String) -> Int32? {
  let len = url.length()
  if len == 0 || !is_scheme_start_char(url.unsafe_get(0).to_int()) {
    return None
  }
  let mut i = 1
  while i < len {
    let code = url.unsafe_get(i).to_int()
    if code == 0x3A {
      if i + 2 < len &&
        url.unsafe_get(i + 1).to_int() == 0x2F &&
        url.unsafe_get(i + 2).to_int() == 0x2F {
        return Some(i)
      }
      return None
    }
    if !is_scheme_char(code) {
      return None
    }
    i = i + 1
  }
  None
}

// The authority of a URL ends at the first `/` (path), `?` (query) or `#`
// (fragment), or at the end of the string.

///|
fn url_authority_end(text : StringView) -> Int32 {
  let len = text.length()
  let mut i = 0
  while i < len {
    let c = text.unsafe_get(i).unsafe_to_char()
    if c == '/' || c == '?' || c == '#' {
      return i
    }
    i = i + 1
  }
  len
}

///|
fn url_authority_has_empty_port(authority : StringView) -> Bool {
  let host_port = match authority.rev_find("@") {
    Some(index) => authority[index + 1:]
    None => authority
  }
  if host_port.has_prefix("[") {
    match host_port.find("]") {
      Some(close) => {
        let rest = host_port[close + 1:]
        rest.length() == 1 && rest.unsafe_get(0).unsafe_to_char() == ':'
      }
      None => false
    }
  } else {
    match host_port.find(":") {
      Some(colon) => colon + 1 == host_port.length()
      None => false
    }
  }
}

// The async HTTP transport treats a trailing colon as part of the hostname,
// so remove an RFC 3986 empty port (which denotes the scheme default) before
// handing the URL over. Other schemes are left untouched so their existing
// transport errors do not change.

///|
fn strip_empty_port(url : String) -> String {
  let colon = match scheme_colon_index(url) {
    Some(value) => value
    None => return url
  }
  let scheme = url[:colon].to_lower()
  if scheme != "http" && scheme != "https" {
    return url
  }
  let authority_start = colon + 3
  let rest = url[authority_start:]
  let authority_end = url_authority_end(rest)
  let authority = rest[:authority_end]
  if !url_authority_has_empty_port(authority) {
    return url
  }
  let sb = StringBuilder(size_hint=url.length())
  sb.write_stringview(url[:authority_start])
  sb.write_stringview(authority[:authority.length() - 1])
  sb.write_stringview(rest[authority_end:])
  sb.to_string()
}

// The URL actually handed to the HTTP transport. `traces_url` intentionally
// preserves fragments for display and configuration inspection, but a
// fragment is never part of an HTTP request target. A network-path reference
// is resolved against the default OTLP/HTTP scheme, the (case-insensitive)
// URI scheme is normalized to lower case, and an empty port is removed.
//
// This does not change `traces_url`, so callers inspecting the configuration
// still see the endpoint they supplied.

///|
pub fn OtlpHttpConfig::request_url(self : OtlpHttpConfig) -> String {
  let configured = self.traces_url()
  let without_fragment = match configured.find("#") {
    Some(index) => configured[:index].to_owned()
    None => configured
  }
  let with_scheme = if without_fragment.has_prefix("//") &&
    without_fragment.length() > 2 &&
    without_fragment.unsafe_get(2).unsafe_to_char() != '/' {
    "http:" + without_fragment
  } else {
    without_fragment
  }
  let normalized = match scheme_colon_index(with_scheme) {
    Some(colon) => {
      let scheme = with_scheme[:colon].to_owned()
      let lower = scheme.to_lower()
      if lower == scheme {
        with_scheme
      } else {
        lower + with_scheme[colon:].to_owned()
      }
    }
    None => with_scheme
  }
  strip_empty_port(normalized)
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
    url: config.request_url(),
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
    // A config assembled directly from the public fields has not passed
    // through the constructor, so validate again before forwarding a header
    // to the transport.
    if !is_valid_http_header_name(key) || !is_valid_http_header_value(value) {
      continue
    }
    // HTTP header names are case-insensitive, so drop any user-configured
    // `Content-Type`, `Accept` or `Content-Encoding` spelling before adding
    // the protocol's own values, and collapse differently-cased duplicates of
    // other headers. This exporter never compresses request bodies, so a
    // configured `Content-Encoding` would describe the body incorrectly. The
    // transport owns body framing (`Content-Length` / `Transfer-Encoding`), so
    // a configured value cannot contradict the bytes actually sent.
    let lower = key.to_lower()
    if lower != "content-type" &&
      lower != "accept" &&
      lower != "content-encoding" &&
      lower != "content-length" &&
      lower != "transfer-encoding" {
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
