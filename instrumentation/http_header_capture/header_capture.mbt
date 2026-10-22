// Opt-in capture of HTTP request and response headers as span attributes,
// following the OpenTelemetry HTTP semantic conventions.
//
// Header capture is disabled by default and configured with the standard
// `OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_*` environment variables. Each
// variable holds a comma-separated list of header names (matched
// case-insensitively); the wildcard `*` captures every header. Captured values
// are recorded as `http.request.header.<lower-case name>` and
// `http.response.header.<lower-case name>` string-array attributes.

///|
pub const ENV_SERVER_REQUEST_HEADERS : String = "OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST"

///|
pub const ENV_SERVER_RESPONSE_HEADERS : String = "OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_RESPONSE"

///|
pub const ENV_CLIENT_REQUEST_HEADERS : String = "OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_CLIENT_REQUEST"

///|
pub const ENV_CLIENT_RESPONSE_HEADERS : String = "OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_CLIENT_RESPONSE"

// A parsed header-capture configuration. Empty configurations inspect no
// headers and record no attributes.

///|
pub struct HeaderCapture {
  capture_all : Bool
  // Lower-cased header names, mapped to `true` so that duplicates from the
  // configuration are collapsed.
  names : Map[String, Bool]
}

// Parse a comma-separated header list. Names are trimmed and lower-cased;
// empty entries are ignored and `*` enables capture of every header.

///|
pub fn HeaderCapture::parse(spec : String) -> HeaderCapture {
  let names : Map[String, Bool] = Map([])
  let mut capture_all = false
  for item in spec.split(",") {
    let name = item.trim().to_lower().to_owned()
    if name == "*" {
      capture_all = true
    } else if name != "" {
      names.set(name, true)
    }
  }
  { capture_all, names }
}

// Last parsed configuration per environment variable. The raw value is
// compared on each call so environment changes are noticed.

///|
let header_capture_cache : Map[String, (String?, HeaderCapture)] = Map([])

// Read and parse a header-capture configuration from an environment variable.
// A missing or blank variable disables capture.

///|
pub fn HeaderCapture::from_env(variable : String) -> HeaderCapture {
  let raw = @env.get_env_var(variable)
  match header_capture_cache.get(variable) {
    Some((cached_raw, capture)) =>
      if cached_raw == raw {
        capture
      } else {
        let capture = match raw {
          Some(value) => HeaderCapture::parse(value)
          None => HeaderCapture::parse("")
        }
        header_capture_cache.set(variable, (raw, capture))
        capture
      }
    None => {
      let capture = match raw {
        Some(value) => HeaderCapture::parse(value)
        None => HeaderCapture::parse("")
      }
      header_capture_cache.set(variable, (raw, capture))
      capture
    }
  }
}

// Whether this configuration can capture at least one header.

///|
pub fn HeaderCapture::is_enabled(self : HeaderCapture) -> Bool {
  self.capture_all || self.names.length() > 0
}

// Whether `name` is selected by this configuration. Matching is
// case-insensitive, and `*` selects every name.

///|
pub fn HeaderCapture::captures(self : HeaderCapture, name : String) -> Bool {
  if self.capture_all {
    true
  } else if self.names.length() == 0 {
    false
  } else {
    self.names.contains(name.to_lower())
  }
}

// Trim HTTP optional whitespace (SP / HTAB) from both ends of a header value.
// Header values in span attributes follow the semantic conventions and omit
// the surrounding OWS.

///|
fn trim_header_ows(value : StringView) -> StringView {
  let len = value.length()
  let mut start = 0
  while start < len {
    let code = value.unsafe_get(start).to_int()
    if code != 0x20 && code != 0x09 {
      break
    }
    start = start + 1
  }
  let mut end = len
  while end > start {
    let code = value.unsafe_get(end - 1).to_int()
    if code != 0x20 && code != 0x09 {
      break
    }
    end = end - 1
  }
  value.view(start_offset=start, end_offset=end)
}

///|
fn record_headers(
  capture : HeaderCapture,
  prefix : String,
  headers : @http.Headers,
  span : @sdk.SpanSdk,
) -> Unit {
  if capture.capture_all {
    for name, value in headers {
      span.set_attribute(
        prefix + name.to_string().to_lower(),
        @sdk.StringArrayValue([trim_header_ows(value[:]).to_owned()]),
      )
    }
  } else if capture.names.length() > 0 {
    for name, _ in capture.names {
      match headers.get(@http.CaseInsensitiveString(name)) {
        Some(value) =>
          span.set_attribute(
            prefix + name,
            @sdk.StringArrayValue([trim_header_ows(value[:]).to_owned()]),
          )
        None => ()
      }
    }
  }
}

// Record the configured request headers on `span`. Values follow the HTTP
// semantic conventions: one string-array element per header.

///|
pub fn HeaderCapture::record_request(
  self : HeaderCapture,
  headers : @http.Headers,
  span : @sdk.SpanSdk,
) -> Unit {
  record_headers(self, @sdk.HTTP_REQUEST_HEADER_PREFIX, headers, span)
}

// Record the configured response headers on `span`.

///|
pub fn HeaderCapture::record_response(
  self : HeaderCapture,
  headers : @http.Headers,
  span : @sdk.SpanSdk,
) -> Unit {
  record_headers(self, @sdk.HTTP_RESPONSE_HEADER_PREFIX, headers, span)
}
